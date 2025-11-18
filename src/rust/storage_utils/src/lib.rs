use std::{fs::{self, OpenOptions}, io::{self, BufWriter, Write}, path::{Path, PathBuf}, sync::{Arc, OnceLock, mpsc}, thread};

use parking_lot::RwLock;
use rkyv::{Archive, Deserialize, Serialize, api::high::HighValidator, bytecheck::CheckBytes, rancor::Error};

static ASYNC_WRITER: OnceLock<AsyncWriter> = OnceLock::new();

fn async_writer() -> &'static AsyncWriter { ASYNC_WRITER.get_or_init(AsyncWriter::new) }

struct AsyncWriter {
	tx: mpsc::Sender<WriteOp>,
}

enum WriteOp {
	Save { path: PathBuf, data: Vec<u8> },
	Flush { respond_to: mpsc::Sender<()> },
	Shutdown,
}

impl AsyncWriter {
	fn new() -> Self {
		let (tx, rx) = mpsc::channel();

		thread::Builder::new()
			.name("storage-writer".to_owned())
			.spawn(move || {
				while let Ok(op) = rx.recv() {
					match op {
						WriteOp::Save { path, data } => {
							if let Err(e) = Self::write_atomic(&path, &data) {
								eprintln!("[AsyncWriter] Failed to write {}: {}", path.display(), e);
							}
						}
						WriteOp::Flush { respond_to } => {
							let _ = respond_to.send(());
						}
						WriteOp::Shutdown => break,
					}
				}
			})
			.ok();

		Self { tx }
	}

	fn write_atomic(path: &Path, data: &[u8]) -> io::Result<()> {
		let temp_path = path.with_extension("tmp");
		let file = OpenOptions::new().write(true).create(true).truncate(true).open(&temp_path)?;
		let mut writer = BufWriter::new(file);
		writer.write_all(data)?;
		writer.flush()?;
		drop(writer);
		fs::rename(temp_path, path)?;
		Ok(())
	}

	fn save(&self, path: PathBuf, data: Vec<u8>) { let _ = self.tx.send(WriteOp::Save { path, data }); }

	fn flush(&self) {
		let (respond_tx, respond_rx) = mpsc::channel();
		if self.tx.send(WriteOp::Flush { respond_to: respond_tx }).is_ok() {
			let _ = respond_rx.recv();
		}
	}
}

impl Drop for AsyncWriter {
	fn drop(&mut self) {
		self.flush();
		let _ = self.tx.send(WriteOp::Shutdown);
	}
}

pub trait Storage<T>: Send + Sync
where
	T: Send + Sync,
{
	fn new(path: impl AsRef<Path>) -> io::Result<Self>
	where
		Self: Sized;

	fn add(&self, item: T) -> io::Result<()>
	where
		T: Clone;

	fn get_all(&self) -> Arc<Vec<T>>;

	fn get_range(&self, start: usize, count: usize) -> Vec<T>
	where
		T: Clone;

	fn get_filtered<F>(&self, predicate: F) -> Vec<T>
	where
		T: Clone,
		F: Fn(&T) -> bool;

	fn update<F>(&self, updater: F) -> io::Result<bool>
	where
		T: Clone,
		F: FnOnce(&mut Vec<T>) -> bool;

	fn clear(&self) -> io::Result<()>
	where
		T: Clone;

	fn len(&self) -> usize;

	fn is_empty(&self) -> bool;

	fn path(&self) -> &Path;
}

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
	rkyv::from_bytes::<Vec<T>, Error>(&bytes).or_else(|_| Ok(Vec::new()))
}

pub fn save_to_disk<T>(path: &Path, items: &Vec<T>) -> io::Result<()>
where
	T: for<'a> Serialize<
		rkyv::api::high::HighSerializer<rkyv::util::AlignedVec, rkyv::ser::allocator::ArenaHandle<'a>, Error>,
	>,
{
	let bytes = rkyv::to_bytes::<Error>(items).map_err(|e| io::Error::other(format!("rkyv: {e:?}")))?;
	let temp_path = path.with_extension("tmp");
	let file = OpenOptions::new().write(true).create(true).truncate(true).open(&temp_path)?;
	let mut writer = BufWriter::new(file);
	writer.write_all(&bytes)?;
	writer.flush()?;
	drop(writer);
	fs::rename(temp_path, path)?;
	Ok(())
}

#[allow(clippy::rc_buffer)]
pub struct RkyvStorage<T>
where
	T: Archive
		+ for<'a> Serialize<
			rkyv::api::high::HighSerializer<rkyv::util::AlignedVec, rkyv::ser::allocator::ArenaHandle<'a>, Error>,
		>,
	T::Archived:
		for<'a> CheckBytes<HighValidator<'a, Error>> + Deserialize<T, rkyv::rancor::Strategy<rkyv::de::Pool, Error>>,
{
	items: RwLock<Arc<Vec<T>>>,
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

		Ok(Self { items: RwLock::new(Arc::new(items)), path })
	}

	pub fn add(&self, item: T) -> io::Result<()>
	where
		T: Clone,
	{
		Arc::make_mut(&mut self.items.write()).push(item);
		self.save()
	}

	pub fn add_async(&self, item: T)
	where
		T: Clone,
	{
		Arc::make_mut(&mut self.items.write()).push(item);
		self.async_save();
	}

	pub fn insert_at_front(&self, item: T) -> io::Result<()>
	where
		T: Clone,
	{
		Arc::make_mut(&mut self.items.write()).insert(0, item);
		self.save()
	}

	pub fn insert_at_front_async(&self, item: T)
	where
		T: Clone,
	{
		Arc::make_mut(&mut self.items.write()).insert(0, item);
		self.async_save();
	}

	#[inline]
	#[must_use]
	pub fn get_all(&self) -> Arc<Vec<T>> { Arc::clone(&self.items.read()) }

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
	pub fn get_filtered<F>(&self, predicate: F) -> Vec<T>
	where
		T: Clone,
		F: Fn(&T) -> bool,
	{
		self.items.read().iter().filter(|item| predicate(item)).cloned().collect()
	}

	#[must_use]
	pub fn find_index<F>(&self, predicate: F) -> Option<usize>
	where
		F: Fn(&T) -> bool,
	{
		self.items.read().iter().position(predicate)
	}

	#[must_use]
	pub fn len(&self) -> usize { self.items.read().len() }

	#[must_use]
	pub fn is_empty(&self) -> bool { self.items.read().is_empty() }

	pub fn clear(&self) -> io::Result<()>
	where
		T: Clone,
	{
		Arc::make_mut(&mut self.items.write()).clear();
		self.save()
	}

	pub fn trim_to(&self, max: usize) -> io::Result<Vec<T>>
	where
		T: Clone,
	{
		let mut guard = self.items.write();
		let items = Arc::make_mut(&mut guard);
		let removed = if max < items.len() { items.drain(max..).collect() } else { Vec::new() };
		drop(guard);
		if !removed.is_empty() {
			self.save()?;
		}
		Ok(removed)
	}

	pub fn update<F>(&self, updater: F) -> io::Result<bool>
	where
		T: Clone,
		F: FnOnce(&mut Vec<T>) -> bool,
	{
		let mut guard = self.items.write();
		let modified = updater(Arc::make_mut(&mut guard));
		if modified {
			drop(guard);
			self.save()?;
		}
		Ok(modified)
	}

	pub fn update_async<F>(&self, updater: F) -> bool
	where
		T: Clone,
		F: FnOnce(&mut Vec<T>) -> bool,
	{
		let mut guard = self.items.write();
		let modified = updater(Arc::make_mut(&mut guard));
		if modified {
			drop(guard);
			self.async_save();
		}
		modified
	}

	fn save(&self) -> io::Result<()> {
		let items = self.items.read();
		save_to_disk(&self.path, &**items)
	}

	fn async_save(&self) {
		let items = self.items.read();
		if let Ok(bytes) = rkyv::to_bytes::<Error>(&**items).map_err(|e| eprintln!("[async_save] rkyv error: {e:?}")) {
			async_writer().save(self.path.clone(), bytes.to_vec());
		}
	}

	pub fn flush(&self) { async_writer().flush(); }

	#[must_use]
	pub fn path(&self) -> &Path { &self.path }
}

impl<T> Storage<T> for RkyvStorage<T>
where
	T: Archive
		+ Clone
		+ Send
		+ Sync
		+ for<'a> Serialize<
			rkyv::api::high::HighSerializer<rkyv::util::AlignedVec, rkyv::ser::allocator::ArenaHandle<'a>, Error>,
		>,
	T::Archived:
		for<'a> CheckBytes<HighValidator<'a, Error>> + Deserialize<T, rkyv::rancor::Strategy<rkyv::de::Pool, Error>>,
{
	fn new(path: impl AsRef<Path>) -> io::Result<Self> { Self::new(path) }

	fn add(&self, item: T) -> io::Result<()> { self.add(item) }

	fn get_all(&self) -> Arc<Vec<T>> { self.get_all() }

	fn get_range(&self, start: usize, count: usize) -> Vec<T> { self.get_range(start, count) }

	fn get_filtered<F>(&self, predicate: F) -> Vec<T>
	where
		F: Fn(&T) -> bool,
	{
		self.get_filtered(predicate)
	}

	fn update<F>(&self, updater: F) -> io::Result<bool>
	where
		F: FnOnce(&mut Vec<T>) -> bool,
	{
		self.update(updater)
	}

	fn clear(&self) -> io::Result<()> { self.clear() }

	fn len(&self) -> usize { self.len() }

	fn is_empty(&self) -> bool { self.is_empty() }

	fn path(&self) -> &Path { self.path() }
}

#[cfg(test)]
#[allow(clippy::indexing_slicing)]
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
