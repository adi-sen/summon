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

pub struct SearchEngine {
	indexer: Arc<RwLock<indexer::Indexer>>,
	matcher: fuzzy_matcher::FuzzyMatcher,
	cache:   Arc<Mutex<LruCache<String, Vec<SearchResult>>>>,
}

impl SearchEngine {
	pub fn new() -> Self {
		Self {
			indexer: Arc::new(RwLock::new(indexer::Indexer::new())),
			matcher: fuzzy_matcher::FuzzyMatcher::new(),
			cache:   Arc::new(Mutex::new(LruCache::new(std::num::NonZeroUsize::new(100).unwrap()))),
		}
	}

	pub fn search(&self, query: &str, limit: usize) -> Result<Vec<SearchResult>> {
		if query.is_empty() {
			return Err(SearchError::QueryTooShort);
		}

		let cache_key = format!("{query}:{limit}");
		if let Some(cached) = self.cache.lock().get(&cache_key) {
			return Ok(cached.clone());
		}

		let indexer = self.indexer.read();

		let mut matches: Vec<_> = indexer
			.items_iter()
			.filter_map(|item| {
				let score = self.matcher.fuzzy_match(&item.name, query)?;
				let indices = self.matcher.match_indices(&item.name, query).unwrap_or_default();
				Some((item.clone(), score, indices))
			})
			.collect();

		matches.sort_by(|a, b| {
			let score_cmp = b.1.cmp(&a.1);
			if score_cmp != std::cmp::Ordering::Equal {
				return score_cmp;
			}
			// Prefer shorter names
			let len_cmp = a.0.name.len().cmp(&b.0.name.len());
			if len_cmp != std::cmp::Ordering::Equal {
				return len_cmp;
			}
			a.0.name.cmp(&b.0.name)
		});

		let results: Vec<_> = matches
			.into_iter()
			.take(limit)
			.map(|(item, score, match_indices)| SearchResult { item, score, match_indices })
			.collect();

		self.cache.lock().put(cache_key, results.clone());

		Ok(results)
	}

	/// Clear the search cache (call when index is updated)
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
				metadata:  Default::default(),
			});
			indexer.add_item(indexer::IndexedItem {
				id:        "2".into(),
				name:      "Safari".into(),
				item_type: indexer::ItemType::Application,
				path:      Some("/Applications/Safari.app".into()),
				metadata:  Default::default(),
			});
		}

		let results = engine.search("vsc", 10).unwrap();
		assert!(!results.is_empty());
		assert_eq!(results[0].item.name.as_str(), "Visual Studio Code");
	}
}
