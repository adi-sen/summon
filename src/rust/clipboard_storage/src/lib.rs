use bytecheck::CheckBytes;
use rkyv::{Archive, Deserialize, Serialize};
use storage_utils::RkyvStorage;

#[derive(Archive, Deserialize, Serialize, CheckBytes, Debug, Clone, PartialEq, Eq)]
#[rkyv(derive(Debug))]
#[repr(u8)]
pub enum ClipboardItemType {
	Text,
	Image,
	Unknown,
}

impl ClipboardItemType {
	#[must_use]
	pub const fn as_u8(self) -> u8 {
		match self {
			Self::Text => 0,
			Self::Image => 1,
			Self::Unknown => 2,
		}
	}

	#[must_use]
	pub const fn from_u8(value: u8) -> Self {
		match value {
			0 => Self::Text,
			1 => Self::Image,
			_ => Self::Unknown,
		}
	}
}

#[derive(Archive, Deserialize, Serialize, CheckBytes, Debug, Clone, Copy, PartialEq)]
#[rkyv(derive(Debug))]
pub struct ImageSize {
	pub width:  f64,
	pub height: f64,
}

#[derive(Archive, Deserialize, Serialize, CheckBytes, Debug, Clone, PartialEq)]
#[rkyv(derive(Debug))]
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
	#[must_use]
	pub const fn new_text(content: String, timestamp: f64, size: i32, source_app: Option<String>) -> Self {
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

	#[must_use]
	pub const fn new_image(
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

pub type ClipboardStorage = RkyvStorage<ClipboardEntry>;

#[cfg(test)]
#[allow(clippy::indexing_slicing)]
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

		let entry = ClipboardEntry::new_text("Hello, World!".to_owned(), 1_234_567_890.0, 13, Some("TestApp".to_owned()));

		storage.insert_at_front_async(entry);
		assert_eq!(storage.len(), 1);

		let entries = storage.get_all();
		assert_eq!(entries.len(), 1);
		assert_eq!(entries[0].content, "Hello, World!");
	}

	#[test]
	fn test_persistence() {
		let temp = NamedTempFile::new().unwrap();
		let path = temp.path().to_path_buf();

		{
			let storage = ClipboardStorage::new(&path).unwrap();
			let entry = ClipboardEntry::new_text("Persistent data".to_owned(), 1_234_567_890.0, 15, None);
			storage.insert_at_front_async(entry);
			storage.flush();
		}

		let storage = ClipboardStorage::new(&path).unwrap();
		assert_eq!(storage.len(), 1);
		let entries = storage.get_all();
		assert_eq!(entries[0].content, "Persistent data");
	}

	#[test]
	fn test_trim() {
		let temp = NamedTempFile::new().unwrap();
		let storage = ClipboardStorage::new(temp.path()).unwrap();

		for i in 0..10 {
			let entry = ClipboardEntry::new_text(format!("Entry {i}"), 1_234_567_890.0 + f64::from(i), 10, None);
			storage.insert_at_front_async(entry);
		}

		storage.flush();
		assert_eq!(storage.len(), 10);

		let removed = storage.trim_to(5).unwrap();
		assert_eq!(removed.len(), 5);
		assert_eq!(storage.len(), 5);
	}
}
