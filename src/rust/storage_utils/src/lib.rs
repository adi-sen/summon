use std::{fs::{self, OpenOptions}, io::{self, BufWriter, Write}, path::{Path, PathBuf}, sync::Arc};

use parking_lot::RwLock;
use rkyv::{Archive, Deserialize, Serialize, api::high::HighValidator, bytecheck::CheckBytes, rancor::Error};

pub fn load_from_disk<T>(path: &Path) -> io::Result<Vec<T>>
where
	T: Archive,
	T::Archived:
		for<'a> CheckBytes<HighValidator<'a, Error>> + Deserialize<T, rkyv::rancor::Strategy<rkyv::de::Pool, Error>>,
{
	let bytes = fs::read(path)?;

	if bytes.is_empty() {
		return Ok(Vec::new());
	}

	rkyv::from_bytes::<Vec<T>, Error>(&bytes).or_else(|_| {
		eprintln!("Warning: Incompatible data format in {}. Starting fresh.", path.display());
		Ok(Vec::new())
	})
}

pub fn save_to_disk<T>(path: &Path, items: &Vec<T>) -> io::Result<()>
where
	T: for<'a> Serialize<
		rkyv::api::high::HighSerializer<rkyv::util::AlignedVec, rkyv::ser::allocator::ArenaHandle<'a>, Error>,
	>,
{
	let bytes =
		rkyv::to_bytes::<Error>(items).map_err(|e| io::Error::other(format!("rkyv serialization error: {e:?}")))?;

	let temp_path = path.with_extension("tmp");
	let file = OpenOptions::new().write(true).create(true).truncate(true).open(&temp_path)?;

	let mut writer = BufWriter::new(file);
	writer.write_all(&bytes)?;
	writer.flush()?;
	drop(writer);

	fs::rename(temp_path, path)?;
	Ok(())
}

pub struct RkyvStorage<T>
where
	T: Archive
		+ for<'a> Serialize<
			rkyv::api::high::HighSerializer<rkyv::util::AlignedVec, rkyv::ser::allocator::ArenaHandle<'a>, Error>,
		>,
	T::Archived:
		for<'a> CheckBytes<HighValidator<'a, Error>> + Deserialize<T, rkyv::rancor::Strategy<rkyv::de::Pool, Error>>,
{
	items: Arc<RwLock<Vec<T>>>,
	path:  PathBuf,
}

impl<T> RkyvStorage<T>
where
	T: Archive
		+ for<'a> Serialize<
			rkyv::api::high::HighSerializer<rkyv::util::AlignedVec, rkyv::ser::allocator::ArenaHandle<'a>, Error>,
		>,
	T::Archived:
		for<'a> CheckBytes<HighValidator<'a, Error>> + Deserialize<T, rkyv::rancor::Strategy<rkyv::de::Pool, Error>>,
{
	pub fn new(path: impl AsRef<Path>) -> io::Result<Self> {
		let path = path.as_ref().to_path_buf();

		if let Some(parent) = path.parent() {
			fs::create_dir_all(parent)?;
		}

		let items = if path.exists() { load_from_disk(&path)? } else { Vec::new() };

		Ok(Self { items: Arc::new(RwLock::new(items)), path })
	}

	pub fn add(&self, item: T) -> io::Result<()> {
		self.items.write().push(item);
		self.save()
	}

	pub fn insert_at_front(&self, item: T) -> io::Result<()> {
		self.items.write().insert(0, item);
		self.save()
	}

	#[must_use]
	pub fn get_all(&self) -> Vec<T>
	where
		T: Clone,
	{
		self.items.read().clone()
	}

	#[must_use]
	pub fn get_range(&self, start: usize, count: usize) -> Vec<T>
	where
		T: Clone,
	{
		let items = self.items.read();
		let end = start.saturating_add(count).min(items.len());
		items.get(start..end).map_or_else(Vec::new, <[T]>::to_vec)
	}

	#[must_use]
	pub fn len(&self) -> usize { self.items.read().len() }

	#[must_use]
	pub fn is_empty(&self) -> bool { self.items.read().is_empty() }

	pub fn clear(&self) -> io::Result<()> {
		self.items.write().clear();
		self.save()
	}

	pub fn trim_to(&self, max: usize) -> io::Result<Vec<T>>
	where
		T: Clone,
	{
		let mut items = self.items.write();
		let removed = if max < items.len() { items.drain(max..).collect() } else { Vec::new() };
		drop(items);
		if !removed.is_empty() {
			self.save()?;
		}
		Ok(removed)
	}

	pub fn update<F>(&self, updater: F) -> io::Result<bool>
	where
		F: FnOnce(&mut Vec<T>) -> bool,
	{
		let modified = updater(&mut self.items.write());
		if modified {
			self.save()?;
		}
		Ok(modified)
	}

	fn save(&self) -> io::Result<()> {
		let items = self.items.read();
		save_to_disk(&self.path, &*items)
	}

	#[must_use]
	pub fn path(&self) -> &Path { &self.path }
}

#[cfg(test)]
mod tests {
	use std::io::Write;

	use bytecheck::CheckBytes;
	use rkyv::{Archive, Deserialize, Serialize};
	use tempfile::NamedTempFile;

	use super::*;

	#[derive(Archive, Deserialize, Serialize, Debug, Clone, PartialEq, CheckBytes)]
	#[rkyv(derive(Debug))]
	struct TestItem {
		id:   String,
		name: String,
	}

	#[test]
	fn test_save_and_load() -> io::Result<()> {
		let temp = NamedTempFile::new()?;
		let path = temp.path();

		let items = vec![TestItem { id: "1".to_owned(), name: "Item 1".to_owned() }, TestItem {
			id:   "2".to_owned(),
			name: "Item 2".to_owned(),
		}];

		save_to_disk(path, &items)?;
		let loaded: Vec<TestItem> = load_from_disk(path)?;

		assert_eq!(loaded.len(), 2);
		assert_eq!(loaded[0].name, "Item 1");
		assert_eq!(loaded[1].name, "Item 2");
		Ok(())
	}

	#[test]
	fn test_load_empty_file() -> io::Result<()> {
		let mut temp = NamedTempFile::new()?;
		temp.write_all(b"")?;
		let path = temp.path();

		let loaded: Vec<TestItem> = load_from_disk(path)?;
		assert_eq!(loaded.len(), 0);
		Ok(())
	}

	#[test]
	fn test_atomic_write() -> io::Result<()> {
		let temp = NamedTempFile::new()?;
		let path = temp.path().to_path_buf();

		let items = vec![TestItem { id: "1".to_owned(), name: "Test".to_owned() }];

		save_to_disk(&path, &items)?;

		let items2 = vec![TestItem { id: "1".to_owned(), name: "Updated".to_owned() }, TestItem {
			id:   "2".to_owned(),
			name: "New".to_owned(),
		}];
		save_to_disk(&path, &items2)?;

		let loaded: Vec<TestItem> = load_from_disk(&path)?;
		assert_eq!(loaded.len(), 2);
		assert_eq!(loaded[0].name, "Updated");
		Ok(())
	}
}
