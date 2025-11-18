use bytecheck::CheckBytes;
use rkyv::{Archive, Deserialize, Serialize};
use storage_utils::RkyvStorage;

#[derive(Archive, Deserialize, Serialize, CheckBytes, Debug, Clone)]
#[rkyv(derive(Debug))]
pub struct AppEntry {
	pub name: String,
	pub path: String,
}

impl AppEntry {
	#[must_use]
	pub const fn new(name: String, path: String) -> Self { Self { name, path } }
}

pub type AppStorage = RkyvStorage<AppEntry>;

#[cfg(test)]
#[allow(clippy::indexing_slicing)]
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

		let entry = AppEntry::new("Safari".to_owned(), "/Applications/Safari.app".to_owned());

		storage.add(entry).unwrap();
		assert_eq!(storage.len(), 1);

		let entries = storage.get_all();
		assert_eq!(entries.len(), 1);
		assert_eq!(entries[0].name, "Safari");
	}

	#[test]
	fn test_persistence() {
		let temp = NamedTempFile::new().unwrap();
		let path = temp.path().to_path_buf();

		{
			let storage = AppStorage::new(&path).unwrap();
			let entry = AppEntry::new("Xcode".to_owned(), "/Applications/Xcode.app".to_owned());
			storage.add(entry).unwrap();
		}

		let storage = AppStorage::new(&path).unwrap();
		assert_eq!(storage.len(), 1);
		let entries = storage.get_all();
		assert_eq!(entries[0].name, "Xcode");
	}
}
