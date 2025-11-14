use std::sync::Arc;

use compact_str::CompactString;
use rustc_hash::{FxBuildHasher, FxHashMap};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ItemType {
	Application,
	File,
	Snippet,
	ClipboardEntry,
	Custom(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IndexedItem {
	pub id:        CompactString,
	pub name:      CompactString,
	pub item_type: ItemType,
	pub path:      Option<CompactString>,
	pub metadata:  FxHashMap<CompactString, CompactString>,
}

pub struct Indexer {
	items: FxHashMap<CompactString, Arc<IndexedItem>>,
	stats: IndexStats,
}

#[derive(Debug, Default)]
struct IndexStats {
	total_items: usize,
	apps:        usize,
	files:       usize,
	snippets:    usize,
}

impl Indexer {
	#[inline]
	#[must_use]
	pub fn new() -> Self {
		Self { items: FxHashMap::with_capacity_and_hasher(100, FxBuildHasher), stats: IndexStats::default() }
	}

	#[inline]
	pub fn add_item(&mut self, item: IndexedItem) {
		let is_new = !self.items.contains_key(&item.id);
		if is_new {
			self.update_stats(&item.item_type, 1);
		}
		let id = item.id.clone();
		self.items.insert(id, Arc::new(item));
	}

	pub fn add_items(&mut self, items: Vec<IndexedItem>) {
		self.items.reserve(items.len());

		for item in items {
			let is_new = !self.items.contains_key(&item.id);
			if is_new {
				self.update_stats(&item.item_type, 1);
			}
			let id = item.id.clone();
			self.items.insert(id, Arc::new(item));
		}
	}

	#[inline]
	pub fn remove_item(&mut self, id: &str) -> Option<Arc<IndexedItem>> {
		self.items.remove(id).inspect(|item| self.update_stats(&item.item_type, -1))
	}

	#[inline]
	#[allow(clippy::cast_sign_loss, clippy::cast_possible_wrap, clippy::cast_possible_truncation)]
	fn update_stats(&mut self, item_type: &ItemType, delta: i32) {
		self.stats.total_items = (self.stats.total_items as i32 + delta) as usize;
		match item_type {
			ItemType::Application => self.stats.apps = (self.stats.apps as i32 + delta) as usize,
			ItemType::File => self.stats.files = (self.stats.files as i32 + delta) as usize,
			ItemType::Snippet => self.stats.snippets = (self.stats.snippets as i32 + delta) as usize,
			_ => {}
		}
	}

	#[inline]
	pub fn items_iter(&self) -> impl Iterator<Item = Arc<IndexedItem>> + '_ { self.items.values().map(Arc::clone) }

	#[inline]
	#[must_use]
	pub fn get_item(&self, id: &str) -> Option<Arc<IndexedItem>> { self.items.get(id).map(Arc::clone) }

	#[inline]
	#[must_use]
	pub fn get_items_by_type(&self, item_type: &ItemType) -> Vec<Arc<IndexedItem>> {
		self.items.values().filter(|item| &item.item_type == item_type).map(Arc::clone).collect()
	}

	#[inline]
	pub fn clear(&mut self) {
		self.items.clear();
		self.stats = IndexStats::default();
	}

	#[inline]
	#[must_use]
	pub const fn stats(&self) -> (usize, usize, usize, usize) {
		(self.stats.total_items, self.stats.apps, self.stats.files, self.stats.snippets)
	}
}

impl Default for Indexer {
	fn default() -> Self { Self::new() }
}

#[cfg(test)]
mod tests {
	use super::*;

	#[test]
	fn test_add_and_get_item() {
		let mut indexer = Indexer::new();
		let item = IndexedItem {
			id:        "test1".into(),
			name:      "Test App".into(),
			item_type: ItemType::Application,
			path:      Some("/Applications/Test.app".into()),
			metadata:  FxHashMap::default(),
		};

		indexer.add_item(item.clone());
		assert_eq!(indexer.get_item("test1").unwrap().name.as_str(), "Test App");
	}

	#[test]
	fn test_remove_item() {
		let mut indexer = Indexer::new();
		let item = IndexedItem {
			id:        "test1".into(),
			name:      "Test App".into(),
			item_type: ItemType::Application,
			path:      None,
			metadata:  FxHashMap::default(),
		};

		indexer.add_item(item);
		assert!(indexer.remove_item("test1").is_some());
		assert!(indexer.get_item("test1").is_none());
	}

	#[test]
	fn test_stats() {
		let mut indexer = Indexer::new();

		indexer.add_item(IndexedItem {
			id:        "app1".into(),
			name:      "App".into(),
			item_type: ItemType::Application,
			path:      None,
			metadata:  FxHashMap::default(),
		});

		indexer.add_item(IndexedItem {
			id:        "file1".into(),
			name:      "File".into(),
			item_type: ItemType::File,
			path:      None,
			metadata:  FxHashMap::default(),
		});

		let (total, apps, files, _) = indexer.stats();
		assert_eq!(total, 2);
		assert_eq!(apps, 1);
		assert_eq!(files, 1);
	}
}
