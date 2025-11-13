pub mod file_scanner;
pub mod fuzzy_matcher;
pub mod indexer;

use std::{fmt, io, sync::Arc};

use lru::LruCache;
use parking_lot::{Mutex, RwLock};

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

pub struct SearchEngine {
	indexer:      Arc<RwLock<indexer::Indexer>>,
	matcher:      fuzzy_matcher::FuzzyMatcher,
	cache:        Arc<Mutex<LruCache<String, Vec<SearchResult>>>>,
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

	pub fn search(&self, query: &str, limit: usize) -> Result<Vec<SearchResult>> {
		if query.is_empty() {
			return Err(SearchError::QueryTooShort);
		}

		let cache_key = query.to_string();
		if let Some(cached) = self.cache.lock().get(&cache_key) {
			return Ok(cached.iter().take(limit).cloned().collect());
		}

		let indexer = self.indexer.read();

		let mut matches: Vec<_> = indexer
			.items_iter()
			.filter_map(|item| {
				let (score, indices) = self.matcher.match_with_indices(&item.name, query)?;
				Some((item.clone(), score, indices))
			})
			.collect();

		if let Some(ref scanner) = self.file_scanner {
			let file_items = scanner.read().scan();
			for item in file_items {
				if let Some((score, indices)) = self.matcher.match_with_indices(&item.name, query) {
					matches.push((item, score, indices));
				}
			}
		}

		matches.sort_unstable_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.name.cmp(&b.0.name)));

		let results: Vec<_> =
			matches.into_iter().map(|(item, score, match_indices)| SearchResult { item, score, match_indices }).collect();

		self.cache.lock().put(cache_key, results.clone());
		Ok(results.into_iter().take(limit).collect())
	}

	pub fn clear_cache(&self) { self.cache.lock().clear(); }

	pub fn indexer(&self) -> Arc<RwLock<indexer::Indexer>> { Arc::clone(&self.indexer) }
}

impl Default for SearchEngine {
	fn default() -> Self { Self::new() }
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct SearchResult {
	pub item:          indexer::IndexedItem,
	pub score:         i64,
	pub match_indices: Vec<usize>,
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
