//! Application storage using rkyv for zero-copy deserialization.

use std::{io, path::Path};

use rkyv::{Archive, Deserialize, Serialize};
use storage_utils::RkyvStorage;

/// A single application entry
#[derive(Archive, Deserialize, Serialize, Debug, Clone)]
#[archive(compare(PartialEq))]
#[archive_attr(derive(Debug))]
pub struct AppEntry {
	pub name: String,
	pub path: String,
}

impl AppEntry {
	pub fn new(name: String, path: String) -> Self { Self { name, path } }
}

/// Application cache storage
pub struct AppStorage {
	storage: RkyvStorage<AppEntry>,
}

impl AppStorage {
	pub fn new<P: AsRef<Path>>(path: P) -> io::Result<Self> { Ok(Self { storage: RkyvStorage::new(path)? }) }

	pub fn add_entry(&self, entry: AppEntry) -> io::Result<()> { self.storage.add(entry) }

	pub fn get_entries(&self) -> Vec<AppEntry> { self.storage.get_all() }

	pub fn len(&self) -> usize { self.storage.len() }

	pub fn is_empty(&self) -> bool { self.storage.is_empty() }

	pub fn clear(&self) -> io::Result<()> { self.storage.clear() }
}

#[cfg(test)]
mod tests {
	use tempfile::NamedTempFile;

	use super::*;

	#[test]
	fn test_new_storage() {
		let temp = NamedTempFile::new().unwrap();
		let storage = AppStorage::new(temp.path()).unwrap();
		assert_eq!(storage.len(), 0);
		assert!(storage.is_empty());
	}

	#[test]
	fn test_add_and_retrieve() {
		let temp = NamedTempFile::new().unwrap();
		let storage = AppStorage::new(temp.path()).unwrap();

		let entry = AppEntry::new("Safari".to_string(), "/Applications/Safari.app".to_string());

		storage.add_entry(entry.clone()).unwrap();
		assert_eq!(storage.len(), 1);

		let entries = storage.get_entries();
		assert_eq!(entries.len(), 1);
		assert_eq!(entries[0].name, "Safari");
	}

	#[test]
	fn test_persistence() {
		let temp = NamedTempFile::new().unwrap();
		let path = temp.path().to_path_buf();

		{
			let storage = AppStorage::new(&path).unwrap();
			let entry = AppEntry::new("Xcode".to_string(), "/Applications/Xcode.app".to_string());
			storage.add_entry(entry).unwrap();
		}

		let storage = AppStorage::new(&path).unwrap();
		assert_eq!(storage.len(), 1);
		let entries = storage.get_entries();
		assert_eq!(entries[0].name, "Xcode");
	}
}
