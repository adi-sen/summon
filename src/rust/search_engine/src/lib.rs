pub mod file_scanner;
pub mod fuzzy_matcher;
pub mod indexer;

use std::{fmt, io, sync::Arc};

use lru::LruCache;
use parking_lot::{Mutex, RwLock};
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

const CACHE_SIZE: usize = 20;
const PARALLEL_THRESHOLD: usize = 500;
const SMALL_VEC_SIZE: usize = 64;

type ResultCache = Arc<Mutex<LruCache<String, Arc<Vec<SearchResult>>>>>;
type MatchTuple = (indexer::IndexedItem, i64, Vec<usize>);
type MatchVec = SmallVec<[MatchTuple; SMALL_VEC_SIZE]>;

pub struct SearchEngine {
	indexer:      Arc<RwLock<indexer::Indexer>>,
	matcher:      fuzzy_matcher::FuzzyMatcher,
	cache:        ResultCache,
	file_scanner: Option<Arc<RwLock<file_scanner::FileScanner>>>,
}

impl SearchEngine {
	#[must_use]
	pub fn new() -> Self {
		Self {
			indexer:      Arc::new(RwLock::new(indexer::Indexer::new())),
			matcher:      fuzzy_matcher::FuzzyMatcher::new(),
			cache:        Arc::new(Mutex::new(LruCache::new(unsafe { std::num::NonZeroUsize::new_unchecked(CACHE_SIZE) }))),
			file_scanner: None,
		}
	}

	pub fn enable_file_search(&mut self, directories: Vec<std::path::PathBuf>, extensions: Option<Vec<String>>) {
		self.file_scanner = Some(Arc::new(RwLock::new(file_scanner::FileScanner::new(directories, extensions))));
	}

	pub fn disable_file_search(&mut self) { self.file_scanner = None; }

	#[inline]
	pub fn search(&self, query: &str, limit: usize) -> Result<Vec<SearchResult>> {
		if query.is_empty() {
			return Err(SearchError::QueryTooShort);
		}

		let cache_key = query.to_string();
		{
			let mut cache = self.cache.lock();
			if let Some(cached) = cache.get(&cache_key) {
				return Ok(cached.iter().take(limit).cloned().collect());
			}
		}

		let pattern = fuzzy_matcher::FuzzyMatcher::parse_pattern(query);
		let indexer = self.indexer.read();
		let items_count = indexer.items_iter().size_hint().0;

		let mut matches: MatchVec = if items_count >= PARALLEL_THRESHOLD {
			let vec: Vec<_> = indexer
				.items_iter()
				.par_bridge()
				.filter_map(|item| {
					let (score, indices) = self.matcher.match_with_pattern(&pattern, &item.name, query)?;
					Some((item.clone(), score, indices))
				})
				.collect();
			SmallVec::from_vec(vec)
		} else {
			let mut m = SmallVec::with_capacity(items_count.min(SMALL_VEC_SIZE));
			for item in indexer.items_iter() {
				if let Some((score, indices)) = self.matcher.match_with_pattern(&pattern, &item.name, query) {
					m.push((item.clone(), score, indices));
				}
			}
			m
		};

		if let Some(ref scanner) = self.file_scanner {
			let file_items = scanner.write().scan();
			matches.reserve(file_items.len());
			for item in file_items {
				if let Some((score, indices)) = self.matcher.match_with_pattern(&pattern, &item.name, query) {
					matches.push((item, score, indices));
				}
			}
		}

		if limit < matches.len() {
			matches.select_nth_unstable_by(limit, |a, b| b.1.cmp(&a.1).then_with(|| a.0.name.cmp(&b.0.name)));
			matches.truncate(limit);
		}

		matches.sort_unstable_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.name.cmp(&b.0.name)));

		let results: Vec<_> =
			matches.into_iter().map(|(item, score, match_indices)| SearchResult { item, score, match_indices }).collect();

		let results = Arc::new(results);
		self.cache.lock().put(cache_key, Arc::clone(&results));
		Ok(Arc::try_unwrap(results).unwrap_or_else(|arc| (*arc).clone()))
	}

	pub fn clear_cache(&self) { self.cache.lock().clear(); }

	pub fn indexer(&self) -> Arc<RwLock<indexer::Indexer>> { Arc::clone(&self.indexer) }
}

impl Default for SearchEngine {
	fn default() -> Self { Self::new() }
}

#[derive(Debug, Clone)]
pub struct SearchResult {
	pub item:          indexer::IndexedItem,
	pub score:         i64,
	pub match_indices: Vec<usize>,
}

impl serde::Serialize for SearchResult {
	fn serialize<S>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error>
	where
		S: serde::Serializer,
	{
		use serde::ser::SerializeStruct;
		let mut state = serializer.serialize_struct("SearchResult", 3)?;
		state.serialize_field("item", &self.item)?;
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
		Ok(SearchResult { item: helper.item, score: helper.score, match_indices: helper.match_indices })
	}
}

#[cfg(test)]
mod tests {
	use rustc_hash::FxHashMap as HashMap;

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
				metadata:  HashMap::default(),
			});
			indexer.add_item(indexer::IndexedItem {
				id:        "2".into(),
				name:      "Safari".into(),
				item_type: indexer::ItemType::Application,
				path:      Some("/Applications/Safari.app".into()),
				metadata:  HashMap::default(),
			});
		}

		let results = engine.search("vsc", 10).unwrap();
		assert!(!results.is_empty());
		assert_eq!(results[0].item.name.as_str(), "Visual Studio Code");
	}
}
