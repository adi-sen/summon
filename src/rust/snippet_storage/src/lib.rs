use std::{io, path::Path};

use bytecheck::CheckBytes;
use rkyv::{Archive, Deserialize, Serialize};
use storage_utils::RkyvStorage;

#[derive(Archive, Deserialize, Serialize, CheckBytes, Debug, Clone, PartialEq)]
#[rkyv(derive(Debug))]
pub struct Snippet {
	pub id:       String,
	pub trigger:  String,
	pub content:  String,
	pub enabled:  bool,
	pub category: String,
}

impl Snippet {
	#[must_use]
	pub fn new(trigger: String, content: String) -> Self {
		Self { id: uuid::Uuid::new_v4().to_string(), trigger, content, enabled: true, category: "General".to_owned() }
	}

	#[must_use]
	pub fn with_category(trigger: String, content: String, category: String) -> Self {
		Self { id: uuid::Uuid::new_v4().to_string(), trigger, content, enabled: true, category }
	}

	#[must_use]
	pub fn with_all(id: String, trigger: String, content: String, enabled: bool, category: String) -> Self {
		Self { id, trigger, content, enabled, category }
	}
}

pub struct SnippetStorage {
	storage: RkyvStorage<Snippet>,
}

impl SnippetStorage {
	pub fn new<P: AsRef<Path>>(path: P) -> io::Result<Self> { Ok(Self { storage: RkyvStorage::new(path)? }) }

	#[must_use]
	pub fn get_all(&self) -> Vec<Snippet> { self.storage.get_all() }

	#[must_use]
	pub fn get_enabled(&self) -> Vec<Snippet> { self.storage.get_all().into_iter().filter(|s| s.enabled).collect() }

	pub fn add(&self, snippet: Snippet) -> io::Result<()> { self.storage.add(snippet) }

	pub fn update(&self, snippet: Snippet) -> io::Result<bool> {
		self.storage.update(|snippets| {
			if let Some(s) = snippets.iter_mut().find(|s| s.id == snippet.id) {
				*s = snippet;
				true
			} else {
				false
			}
		})
	}

	pub fn delete(&self, id: &str) -> io::Result<bool> {
		self.storage.update(|snippets| {
			let before_len = snippets.len();
			snippets.retain(|s| s.id != id);
			snippets.len() != before_len
		})
	}

	#[must_use]
	pub fn len(&self) -> usize { self.storage.len() }

	#[must_use]
	pub fn is_empty(&self) -> bool { self.storage.is_empty() }
}

#[cfg(test)]
mod tests {
	use tempfile::NamedTempFile;

	use super::*;

	#[test]
	fn test_new_storage() {
		let temp = NamedTempFile::new().unwrap();
		let storage = SnippetStorage::new(temp.path()).unwrap();
		assert_eq!(storage.len(), 0);
		assert!(storage.is_empty());
	}

	#[test]
	fn test_add_and_retrieve() {
		let temp = NamedTempFile::new().unwrap();
		let storage = SnippetStorage::new(temp.path()).unwrap();

		let snippet = Snippet::new("\\email".to_owned(), "test@example.com".to_owned());
		storage.add(snippet.clone()).unwrap();

		assert_eq!(storage.len(), 1);

		let snippets = storage.get_all();
		assert_eq!(snippets.len(), 1);
		assert_eq!(snippets[0].trigger, "\\email");
		assert_eq!(snippets[0].content, "test@example.com");
	}

	#[test]
	fn test_persistence() {
		let temp = NamedTempFile::new().unwrap();
		let path = temp.path().to_path_buf();

		{
			let storage = SnippetStorage::new(&path).unwrap();
			let snippet = Snippet::new("\\test".to_owned(), "Test content".to_owned());
			storage.add(snippet).unwrap();
		}

		let storage = SnippetStorage::new(&path).unwrap();
		assert_eq!(storage.len(), 1);
		let snippets = storage.get_all();
		assert_eq!(snippets[0].trigger, "\\test");
	}

	#[test]
	fn test_update() {
		let temp = NamedTempFile::new().unwrap();
		let storage = SnippetStorage::new(temp.path()).unwrap();

		let snippet = Snippet::new("\\test".to_owned(), "Original".to_owned());
		storage.add(snippet.clone()).unwrap();

		let mut updated = snippet.clone();
		updated.content = "Updated".to_owned();
		let result = storage.update(updated).unwrap();
		assert!(result);

		let snippets = storage.get_all();
		assert_eq!(snippets[0].content, "Updated");
	}

	#[test]
	fn test_delete() {
		let temp = NamedTempFile::new().unwrap();
		let storage = SnippetStorage::new(temp.path()).unwrap();

		let snippet = Snippet::new("\\test".to_owned(), "Content".to_owned());
		let id = snippet.id.clone();
		storage.add(snippet).unwrap();

		assert_eq!(storage.len(), 1);
		let deleted = storage.delete(&id).unwrap();
		assert!(deleted);
		assert_eq!(storage.len(), 0);
	}
}
