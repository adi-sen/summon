use std::{io, path::Path, sync::Arc};

use bytecheck::CheckBytes;
use rkyv::{Archive, Deserialize, Serialize};
use storage_utils::RkyvStorage;

#[derive(Archive, Deserialize, Serialize, CheckBytes, Debug, Clone, PartialEq, Eq)]
#[rkyv(derive(Debug))]
#[derive(serde::Serialize, serde::Deserialize)]
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
		Self { id: uuid::Uuid::new_v4().to_string(), trigger, content, enabled: true, category: "General".into() }
	}

	#[must_use]
	pub fn with_category(trigger: String, content: String, category: String) -> Self {
		Self { id: uuid::Uuid::new_v4().to_string(), trigger, content, enabled: true, category }
	}

	#[must_use]
	pub const fn with_all(id: String, trigger: String, content: String, enabled: bool, category: String) -> Self {
		Self { id, trigger, content, enabled, category }
	}
}

pub struct SnippetStorage {
	storage: RkyvStorage<Snippet>,
}

impl SnippetStorage {
	pub fn new<P: AsRef<Path>>(path: P) -> io::Result<Self> { Ok(Self { storage: RkyvStorage::new(path)? }) }

	#[must_use]
	pub fn get_all(&self) -> Arc<Vec<Snippet>> { self.storage.get_all() }

	#[must_use]
	pub fn get_enabled(&self) -> Vec<Snippet> { self.storage.get_filtered(|s| s.enabled) }

	pub fn add(&self, snippet: Snippet) { self.storage.add_async(snippet); }

	pub fn update(&self, snippet: Snippet) -> bool {
		self.storage.update_async(|snippets| {
			snippets.iter_mut().find(|s| s.id == snippet.id).is_some_and(|s| {
				*s = snippet;
				true
			})
		})
	}

	pub fn delete(&self, id: &str) -> bool {
		self.storage.update_async(|snippets| {
			let before_len = snippets.len();
			snippets.retain(|s| s.id != id);
			snippets.len() != before_len
		})
	}

	#[must_use]
	pub fn len(&self) -> usize { self.storage.len() }

	#[must_use]
	pub fn is_empty(&self) -> bool { self.storage.is_empty() }

	pub fn flush(&self) { self.storage.flush(); }

	pub fn export_to_json(&self) -> Result<String, String> {
		let snippets = self.storage.get_all();
		serde_json::to_string_pretty(&*snippets).map_err(|e| format!("Failed to serialize snippets: {e}"))
	}

	pub fn import_from_json(&self, json: &str, merge: bool) -> Result<usize, String> {
		let imported: Vec<Snippet> = serde_json::from_str(json).map_err(|e| format!("Failed to parse JSON: {e}"))?;

		if !merge {
			self.storage.clear().map_err(|e| format!("Failed to clear existing snippets: {e}"))?;
		}

		let mut count = 0;
		for snippet in imported {
			if self.storage.add(snippet).is_ok() {
				count += 1;
			}
		}

		Ok(count)
	}
}

#[cfg(test)]
#[allow(clippy::indexing_slicing)]
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
		storage.add(snippet);

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
			storage.add(snippet);
			storage.flush();
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
		storage.add(snippet.clone());

		let mut updated = snippet;
		updated.content = "Updated".to_owned();
		let result = storage.update(updated);
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
		storage.add(snippet);

		assert_eq!(storage.len(), 1);
		let deleted = storage.delete(&id);
		assert!(deleted);
		assert_eq!(storage.len(), 0);
	}

	#[test]
	fn test_export_import_json() {
		let temp = NamedTempFile::new().unwrap();
		let storage = SnippetStorage::new(temp.path()).unwrap();

		storage.add(Snippet::new("\\email".to_owned(), "test@example.com".to_owned()));
		storage.add(Snippet::with_category("\\phone".to_owned(), "123-456-7890".to_owned(), "Contact".to_owned()));

		let json = storage.export_to_json().unwrap();
		assert!(json.contains("\\email"));
		assert!(json.contains("test@example.com"));

		let temp2 = NamedTempFile::new().unwrap();
		let storage2 = SnippetStorage::new(temp2.path()).unwrap();

		let count = storage2.import_from_json(&json, false).unwrap();
		assert_eq!(count, 2);
		assert_eq!(storage2.len(), 2);

		let snippets = storage2.get_all();
		assert_eq!(snippets[0].trigger, "\\email");
		assert_eq!(snippets[1].category, "Contact");
	}

	#[test]
	fn test_import_merge() {
		let temp = NamedTempFile::new().unwrap();
		let storage = SnippetStorage::new(temp.path()).unwrap();

		storage.add(Snippet::new("\\existing".to_owned(), "Existing".to_owned()));

		let json = r#"[{"id":"test-id","trigger":"\\new","content":"New","enabled":true,"category":"General"}]"#;

		let count = storage.import_from_json(json, true).unwrap();
		assert_eq!(count, 1);
		assert_eq!(storage.len(), 2);
	}
}
