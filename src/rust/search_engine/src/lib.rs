pub mod file_scanner;
pub mod fuzzy_matcher;
pub mod indexer;

use std::{cmp::Reverse, collections::BinaryHeap, fmt, io, num::NonZeroUsize, sync::{Arc, atomic::{AtomicUsize, Ordering}}};

use compact_str::CompactString;
use lru::LruCache;
use parking_lot::RwLock;
use rayon::prelude::*;
use smallvec::SmallVec;

#[derive(Debug)]
pub enum SearchError {
	IndexNotInitialized,
	QueryTooShort,
	Io(io::Error),
}

impl fmt::Display for SearchError {
	fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
		match self {
			Self::IndexNotInitialized => write!(f, "Index not initialized"),
			Self::QueryTooShort => write!(f, "Query too short"),
			Self::Io(e) => write!(f, "IO error: {e}"),
		}
	}
}

impl std::error::Error for SearchError {}

impl From<io::Error> for SearchError {
	fn from(e: io::Error) -> Self { Self::Io(e) }
}

pub type Result<T> = std::result::Result<T, SearchError>;

const CACHE_SIZE: usize = 256;
const CACHE_SIZE_NZ: NonZeroUsize = NonZeroUsize::new(CACHE_SIZE).unwrap();
const PARALLEL_THRESHOLD: usize = 500;
const SMALL_VEC_SIZE: usize = 64;
const HEAP_THRESHOLD: usize = 100;

type ResultCache = Arc<RwLock<LruCache<CompactString, Arc<Vec<SearchResult>>>>>;
type IndicesVec = SmallVec<[usize; 8]>;
type MatchTuple = (Arc<indexer::IndexedItem>, i64, IndicesVec);
type MatchVec = SmallVec<[MatchTuple; SMALL_VEC_SIZE]>;

struct HeapItem(Arc<indexer::IndexedItem>, i64, IndicesVec);

impl Eq for HeapItem {}

impl PartialEq for HeapItem {
	fn eq(&self, other: &Self) -> bool { self.1 == other.1 && self.0.name == other.0.name }
}

impl Ord for HeapItem {
	fn cmp(&self, other: &Self) -> std::cmp::Ordering {
		self.1.cmp(&other.1).then_with(|| other.0.name.cmp(&self.0.name))
	}
}

impl PartialOrd for HeapItem {
	fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> { Some(self.cmp(other)) }
}

pub struct SearchEngine {
	indexer:                 Arc<RwLock<indexer::Indexer>>,
	matcher:                 fuzzy_matcher::FuzzyMatcher,
	cache:                   ResultCache,
	file_scanner:            Option<Arc<RwLock<file_scanner::FileScanner>>>,
	file_indexer:            Option<Arc<file_indexer::FileIndexer>>,
	file_indexer_generation: AtomicUsize,
}

impl SearchEngine {
	#[must_use]
	pub fn new() -> Self {
		Self {
			indexer:                 Arc::new(RwLock::new(indexer::Indexer::new())),
			matcher:                 fuzzy_matcher::FuzzyMatcher::new(),
			cache:                   Arc::new(RwLock::new(LruCache::new(CACHE_SIZE_NZ))),
			file_scanner:            None,
			file_indexer:            None,
			file_indexer_generation: AtomicUsize::new(0),
		}
	}

	pub fn enable_file_search(&mut self, directories: Vec<std::path::PathBuf>, extensions: Option<Vec<String>>) {
		self.file_scanner = Some(Arc::new(RwLock::new(file_scanner::FileScanner::new(directories, extensions))));
	}

	pub fn disable_file_search(&mut self) { self.file_scanner = None; }

	pub fn set_file_indexer(&mut self, indexer: Arc<file_indexer::FileIndexer>) { self.file_indexer = Some(indexer); }

	pub fn clear_file_indexer(&mut self) { self.file_indexer = None; }

	#[inline]
	#[allow(clippy::significant_drop_tightening)]
	pub fn search(&self, query: &str, limit: usize) -> Result<Vec<SearchResult>> {
		if query.is_empty() {
			return Err(SearchError::QueryTooShort);
		}

		self.check_and_invalidate_cache();

		let cache_key = CompactString::new(query);
		{
			let mut cache = self.cache.write();
			if let Some(cached) = cache.get(&cache_key) {
				return Ok(cached.iter().take(limit).cloned().collect());
			}
		}

		let pattern = fuzzy_matcher::FuzzyMatcher::parse_pattern(query);
		let indexer = self.indexer.read();
		let items_count = indexer.items_iter().size_hint().0;

		let use_heap = limit < HEAP_THRESHOLD;

		let results: Vec<SearchResult> = if use_heap {
			let mut heap: BinaryHeap<Reverse<HeapItem>> = BinaryHeap::with_capacity(limit + 1);

			for item in indexer.items_iter() {
				if let Some((score, indices)) = self.matcher.match_with_pattern(&pattern, &item.name, query) {
					heap.push(Reverse(HeapItem(Arc::clone(item), score, indices)));
					if heap.len() > limit {
						heap.pop();
					}
				}
			}

			self.search_files_heap(&pattern, query, &mut heap, limit);

			let mut results: Vec<_> = heap
				.into_iter()
				.map(|Reverse(HeapItem(item, score, indices))| SearchResult { item, score, match_indices: indices })
				.collect();
			results.sort_unstable_by(|a, b| b.score.cmp(&a.score).then_with(|| a.item.name.cmp(&b.item.name)));
			results
		} else {
			let mut matches: MatchVec = if items_count >= PARALLEL_THRESHOLD {
				let vec: Vec<_> = indexer
					.items_iter()
					.par_bridge()
					.filter_map(|item| {
						let matcher = fuzzy_matcher::FuzzyMatcher::new();
						let (score, indices) = matcher.match_with_pattern(&pattern, &item.name, query)?;
						Some((Arc::clone(item), score, indices))
					})
					.collect();
				SmallVec::from_vec(vec)
			} else {
				let mut m = SmallVec::with_capacity(items_count.min(SMALL_VEC_SIZE));
				for item in indexer.items_iter() {
					if let Some((score, indices)) = self.matcher.match_with_pattern(&pattern, &item.name, query) {
						m.push((Arc::clone(item), score, indices));
					}
				}
				m
			};

			self.search_files_vec(&pattern, query, &mut matches);

			if limit < matches.len() {
				matches.select_nth_unstable_by(limit, |a, b| b.1.cmp(&a.1).then_with(|| a.0.name.cmp(&b.0.name)));
				matches.truncate(limit);
			}

			matches.sort_unstable_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.name.cmp(&b.0.name)));

			matches.into_iter().map(|(item, score, match_indices)| SearchResult { item, score, match_indices }).collect()
		};

		let results = Arc::new(results);
		self.cache.write().put(cache_key, results.clone());
		Ok(Arc::unwrap_or_clone(results))
	}

	pub fn clear_cache(&self) { self.cache.write().clear(); }

	pub fn indexer(&self) -> &Arc<RwLock<indexer::Indexer>> { &self.indexer }

	fn check_and_invalidate_cache(&self) {
		if let Some(ref indexer) = self.file_indexer {
			let current_gen = indexer.generation();
			let last_gen = self.file_indexer_generation.load(Ordering::Relaxed);
			if current_gen != last_gen {
				self.invalidate_file_cache();
				self.file_indexer_generation.store(current_gen, Ordering::Relaxed);
			}
		}
	}

	fn invalidate_file_cache(&self) {
		let mut cache = self.cache.write();
		cache.clear();
	}

	fn search_files_heap(
		&self,
		pattern: &fuzzy_matcher::FuzzyPattern,
		query: &str,
		heap: &mut BinaryHeap<Reverse<HeapItem>>,
		limit: usize,
	) {
		if let Some(ref file_idx) = self.file_indexer {
			let file_entries = file_idx.get_all_files();

			for file_entry in &file_entries {
				let item = indexer::IndexedItem {
					id:        CompactString::new(&file_entry.path),
					name:      file_entry.name_compact(),
					item_type: indexer::ItemType::File,
					path:      Some(file_entry.path_compact()),
					metadata:  None,
				};
				if let Some((score, indices)) = self.matcher.match_with_pattern(pattern, &item.name, query) {
					heap.push(Reverse(HeapItem(Arc::new(item), score, indices)));
					if heap.len() > limit {
						heap.pop();
					}
				}
			}
		} else if let Some(ref scanner) = self.file_scanner {
			let file_items = scanner.write().scan();
			for item in file_items.iter() {
				if let Some((score, indices)) = self.matcher.match_with_pattern(pattern, &item.name, query) {
					heap.push(Reverse(HeapItem(Arc::new(item.clone()), score, indices)));
					if heap.len() > limit {
						heap.pop();
					}
				}
			}
		}
	}

	fn search_files_vec(&self, pattern: &fuzzy_matcher::FuzzyPattern, query: &str, matches: &mut MatchVec) {
		if let Some(ref file_idx) = self.file_indexer {
			let file_entries = file_idx.get_all_files();
			matches.reserve(file_entries.len().min(1000));

			if file_entries.len() >= PARALLEL_THRESHOLD {
				let parallel_matches: Vec<_> = file_entries
					.par_iter()
					.filter_map(|file_entry| {
						let matcher = fuzzy_matcher::FuzzyMatcher::new();
						let item = indexer::IndexedItem {
							id:        CompactString::new(&file_entry.path),
							name:      file_entry.name_compact(),
							item_type: indexer::ItemType::File,
							path:      Some(file_entry.path_compact()),
							metadata:  None,
						};
						let (score, indices) = matcher.match_with_pattern(pattern, &item.name, query)?;
						Some((Arc::new(item), score, indices))
					})
					.collect();
				matches.extend(parallel_matches);
			} else {
				for file_entry in &file_entries {
					let item = indexer::IndexedItem {
						id:        CompactString::new(&file_entry.path),
						name:      file_entry.name_compact(),
						item_type: indexer::ItemType::File,
						path:      Some(file_entry.path_compact()),
						metadata:  None,
					};
					if let Some((score, indices)) = self.matcher.match_with_pattern(pattern, &item.name, query) {
						matches.push((Arc::new(item), score, indices));
					}
				}
			}
		} else if let Some(ref scanner) = self.file_scanner {
			let file_items = scanner.write().scan();
			matches.reserve(file_items.len());
			for item in file_items.iter() {
				if let Some((score, indices)) = self.matcher.match_with_pattern(pattern, &item.name, query) {
					matches.push((Arc::new(item.clone()), score, indices));
				}
			}
		}
	}
}

impl Default for SearchEngine {
	fn default() -> Self { Self::new() }
}

#[derive(Debug, Clone)]
pub struct SearchResult {
	pub item:          Arc<indexer::IndexedItem>,
	pub score:         i64,
	pub match_indices: IndicesVec,
}

impl serde::Serialize for SearchResult {
	fn serialize<S>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error>
	where
		S: serde::Serializer,
	{
		use serde::ser::SerializeStruct;
		let mut state = serializer.serialize_struct("SearchResult", 3)?;
		state.serialize_field("item", self.item.as_ref())?;
		state.serialize_field("score", &self.score)?;
		state.serialize_field("match_indices", &self.match_indices)?;
		state.end()
	}
}

impl<'de> serde::Deserialize<'de> for SearchResult {
	fn deserialize<D>(deserializer: D) -> std::result::Result<Self, D::Error>
	where
		D: serde::Deserializer<'de>,
	{
		#[derive(serde::Deserialize)]
		struct SearchResultHelper {
			item:          indexer::IndexedItem,
			score:         i64,
			match_indices: Vec<usize>,
		}

		let helper = SearchResultHelper::deserialize(deserializer)?;
		Ok(Self {
			item:          Arc::new(helper.item),
			score:         helper.score,
			match_indices: SmallVec::from_vec(helper.match_indices),
		})
	}
}

#[cfg(test)]
mod tests {
	use super::*;

	#[test]
	fn test_search_basic() {
		let engine = SearchEngine::new();

		{
			let mut indexer = engine.indexer.write();
			indexer.add_item(indexer::IndexedItem {
				id:        "1".into(),
				name:      "Visual Studio Code".into(),
				item_type: indexer::ItemType::Application,
				path:      Some("/Applications/Visual Studio Code.app".into()),
				metadata:  None,
			});
			indexer.add_item(indexer::IndexedItem {
				id:        "2".into(),
				name:      "Safari".into(),
				item_type: indexer::ItemType::Application,
				path:      Some("/Applications/Safari.app".into()),
				metadata:  None,
			});
		}

		let results = engine.search("vsc", 10).unwrap();
		assert!(!results.is_empty());
		assert_eq!(results[0].item.name.as_str(), "Visual Studio Code");
	}
}
