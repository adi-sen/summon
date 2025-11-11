use std::{io, path::Path};

use rkyv::{Archive, Deserialize, Serialize};
use storage_utils::RkyvStorage;

#[derive(Archive, Deserialize, Serialize, Debug, Clone, PartialEq)]
#[archive(compare(PartialEq))]
#[archive_attr(derive(Debug))]
pub enum ClipboardItemType {
	Text,
	Image,
	Unknown,
}

impl ClipboardItemType {
	pub fn as_u8(self) -> u8 {
		match self {
			ClipboardItemType::Text => 0,
			ClipboardItemType::Image => 1,
			ClipboardItemType::Unknown => 2,
		}
	}

	pub fn from_u8(value: u8) -> Self {
		match value {
			0 => ClipboardItemType::Text,
			1 => ClipboardItemType::Image,
			_ => ClipboardItemType::Unknown,
		}
	}
}

#[derive(Archive, Deserialize, Serialize, Debug, Clone, Copy, PartialEq)]
#[archive(compare(PartialEq))]
#[archive_attr(derive(Debug))]
pub struct ImageSize {
	pub width:  f64,
	pub height: f64,
}

#[derive(Archive, Deserialize, Serialize, Debug, Clone, PartialEq)]
#[archive(compare(PartialEq))]
#[archive_attr(derive(Debug))]
pub struct ClipboardEntry {
	pub content:         String,
	pub timestamp:       f64,
	pub item_type:       ClipboardItemType,
	pub image_file_path: Option<String>,
	pub image_size:      Option<ImageSize>,
	pub size:            i32,
	pub source_app:      Option<String>,
}

impl ClipboardEntry {
	pub fn new_text(content: String, timestamp: f64, size: i32, source_app: Option<String>) -> Self {
		Self {
			content,
			timestamp,
			item_type: ClipboardItemType::Text,
			image_file_path: None,
			image_size: None,
			size,
			source_app,
		}
	}

	pub fn new_image(
		content: String,
		timestamp: f64,
		image_file_path: String,
		width: f64,
		height: f64,
		size: i32,
		source_app: Option<String>,
	) -> Self {
		Self {
			content,
			timestamp,
			item_type: ClipboardItemType::Image,
			image_file_path: Some(image_file_path),
			image_size: Some(ImageSize { width, height }),
			size,
			source_app,
		}
	}
}

pub struct ClipboardStorage {
	storage: RkyvStorage<ClipboardEntry>,
}

impl ClipboardStorage {
	pub fn new<P: AsRef<Path>>(path: P) -> io::Result<Self> { Ok(Self { storage: RkyvStorage::new(path)? }) }

	pub fn add_entry(&self, entry: ClipboardEntry) -> io::Result<()> { self.storage.insert_at_front(entry) }

	pub fn get_entries(&self) -> Vec<ClipboardEntry> { self.storage.get_all() }

	pub fn get_entries_range(&self, start: usize, count: usize) -> Vec<ClipboardEntry> {
		self.storage.get_range(start, count)
	}

	pub fn len(&self) -> usize { self.storage.len() }

	pub fn is_empty(&self) -> bool { self.storage.is_empty() }

	pub fn trim_to(&self, max_entries: usize) -> io::Result<Vec<ClipboardEntry>> { self.storage.trim_to(max_entries) }

	pub fn clear(&self) -> io::Result<()> { self.storage.clear() }

	pub fn remove_at(&self, index: usize) -> io::Result<bool> {
		self.storage.update(|entries| {
			if index < entries.len() {
				entries.remove(index);
				true
			} else {
				false
			}
		})
	}
}

#[cfg(test)]
mod tests {
	use tempfile::NamedTempFile;

	use super::*;

	#[test]
	fn test_new_storage() {
		let temp = NamedTempFile::new().unwrap();
		let storage = ClipboardStorage::new(temp.path()).unwrap();
		assert_eq!(storage.len(), 0);
		assert!(storage.is_empty());
	}

	#[test]
	fn test_add_and_retrieve() {
		let temp = NamedTempFile::new().unwrap();
		let storage = ClipboardStorage::new(temp.path()).unwrap();

		let entry = ClipboardEntry::new_text("Hello, World!".to_string(), 1234567890.0, 13, Some("TestApp".to_string()));

		storage.add_entry(entry.clone()).unwrap();
		assert_eq!(storage.len(), 1);

		let entries = storage.get_entries();
		assert_eq!(entries.len(), 1);
		assert_eq!(entries[0].content, "Hello, World!");
	}

	#[test]
	fn test_persistence() {
		let temp = NamedTempFile::new().unwrap();
		let path = temp.path().to_path_buf();

		{
			let storage = ClipboardStorage::new(&path).unwrap();
			let entry = ClipboardEntry::new_text("Persistent data".to_string(), 1_234_567_890.0, 15, None);
			storage.add_entry(entry).unwrap();
		}

		let storage = ClipboardStorage::new(&path).unwrap();
		assert_eq!(storage.len(), 1);
		let entries = storage.get_entries();
		assert_eq!(entries[0].content, "Persistent data");
	}

	#[test]
	fn test_trim() {
		let temp = NamedTempFile::new().unwrap();
		let storage = ClipboardStorage::new(temp.path()).unwrap();

		for i in 0..10 {
			let entry = ClipboardEntry::new_text(format!("Entry {i}"), 1_234_567_890.0 + i as f64, 10, None);
			storage.add_entry(entry).unwrap();
		}

		assert_eq!(storage.len(), 10);

		let removed = storage.trim_to(5).unwrap();
		assert_eq!(removed.len(), 5);
		assert_eq!(storage.len(), 5);
	}
}
