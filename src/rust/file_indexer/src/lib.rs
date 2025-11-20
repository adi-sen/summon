use std::{fs, io, path::{Path, PathBuf}, sync::{Arc, atomic::{AtomicBool, AtomicUsize, Ordering}}, time::{Duration, SystemTime}};

use bytecheck::CheckBytes;
use compact_str::CompactString;
use crossbeam_channel::{Receiver, unbounded};
use notify::{EventKind, RecommendedWatcher, RecursiveMode};
use notify_debouncer_full::{DebouncedEvent, Debouncer, new_debouncer};
use parking_lot::RwLock;
use rkyv::{Archive, Deserialize, Serialize};
use rustc_hash::{FxBuildHasher, FxHashMap};
use storage_utils::{load_from_disk, save_to_disk};
use unicode_normalization::UnicodeNormalization;

const DEFAULT_MAX_FILES: usize = 10_000;
const DEFAULT_MAX_DEPTH: usize = 5;
const BATCH_SIZE: usize = 1000;

static DEFAULT_EXTENSIONS: &[&str] = &[
	"txt", "md", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv", "json", "xml", "html", "css", "js", "ts",
	"py", "rs", "go", "java", "c", "cpp", "h", "hpp", "swift", "yaml", "yml", "toml", "ini", "cfg", "conf",
];

static EXCLUDED_DIRS: &[&str] =
	&["node_modules", ".git", ".svn", ".hg", "target", "build", "dist", ".cache", "Library", ".Trash", ".cargo"];

fn normalize_path(path: &str) -> String {
	#[cfg(target_os = "macos")]
	{
		path.nfd().collect::<String>().to_lowercase()
	}
	#[cfg(not(target_os = "macos"))]
	{
		path.to_string()
	}
}

#[derive(Archive, Deserialize, Serialize, CheckBytes, Debug, Clone)]
#[rkyv(derive(Debug))]
pub struct FileEntry {
	pub path: String,
	pub name: String,
}

impl FileEntry {
	fn from_path(path: &Path) -> io::Result<Self> {
		let name = path.file_name().and_then(|n| n.to_str()).ok_or_else(|| io::Error::other("invalid filename"))?;

		Ok(Self { path: path.to_string_lossy().into_owned(), name: name.to_owned() })
	}

	#[must_use]
	pub fn path_compact(&self) -> CompactString { CompactString::new(&self.path) }

	#[must_use]
	pub fn name_compact(&self) -> CompactString { CompactString::new(&self.name) }

	#[must_use]
	pub fn normalized_key(&self) -> CompactString { CompactString::new(normalize_path(&self.path)) }
}

#[derive(serde::Serialize, serde::Deserialize)]
pub struct FileIndexerConfig {
	pub enabled:      bool,
	pub directories:  Vec<PathBuf>,
	pub extensions:   Vec<String>,
	pub max_files:    usize,
	pub max_depth:    usize,
	pub index_hidden: bool,
	pub exclude_dirs: Vec<String>,
}

impl Default for FileIndexerConfig {
	fn default() -> Self {
		Self {
			enabled:      false,
			directories:  Vec::new(),
			extensions:   DEFAULT_EXTENSIONS.iter().map(|s| (*s).to_owned()).collect(),
			max_files:    DEFAULT_MAX_FILES,
			max_depth:    DEFAULT_MAX_DEPTH,
			index_hidden: false,
			exclude_dirs: EXCLUDED_DIRS.iter().map(|s| (*s).to_owned()).collect(),
		}
	}
}

type GenerationCallback = extern "C" fn(usize);

pub struct FileIndexer {
	index:               Arc<RwLock<FxHashMap<CompactString, FileEntry>>>,
	config:              Arc<RwLock<FileIndexerConfig>>,
	storage_path:        PathBuf,
	file_count:          Arc<AtomicUsize>,
	generation:          Arc<AtomicUsize>,
	last_scan:           Arc<RwLock<FxHashMap<PathBuf, SystemTime>>>,
	needs_initial:       Arc<AtomicBool>,
	watcher:             Arc<RwLock<Option<Debouncer<RecommendedWatcher, notify_debouncer_full::FileIdMap>>>>,
	generation_callback: Arc<parking_lot::Mutex<Option<GenerationCallback>>>,
}

impl FileIndexer {
	pub fn set_generation_callback(&self, callback: Option<GenerationCallback>) {
		*self.generation_callback.lock() = callback;
	}

	pub fn new(storage_path: impl AsRef<Path>, config: FileIndexerConfig) -> io::Result<Self> {
		let storage_path = storage_path.as_ref().to_path_buf();

		if let Some(parent) = storage_path.parent() {
			fs::create_dir_all(parent)?;
		}

		let index = if storage_path.exists() {
			let entries: Vec<FileEntry> = load_from_disk(&storage_path)?;
			let mut map = FxHashMap::with_capacity_and_hasher(entries.len(), FxBuildHasher);
			for e in entries {
				map.insert(e.normalized_key(), e);
			}
			map
		} else {
			FxHashMap::with_capacity_and_hasher(1024, FxBuildHasher)
		};

		let file_count = index.len();

		Ok(Self {
			index: Arc::new(RwLock::new(index)),
			config: Arc::new(RwLock::new(config)),
			storage_path,
			file_count: Arc::new(AtomicUsize::new(file_count)),
			generation: Arc::new(AtomicUsize::new(0)),
			last_scan: Arc::new(RwLock::new(FxHashMap::default())),
			needs_initial: Arc::new(AtomicBool::new(true)),
			watcher: Arc::new(RwLock::new(None)),
			generation_callback: Arc::new(parking_lot::Mutex::new(None)),
		})
	}

	fn start_file_watcher(&self) -> io::Result<()> {
		let index = Arc::clone(&self.index);
		let generation = Arc::clone(&self.generation);
		let config = Arc::clone(&self.config);
		let file_count = Arc::clone(&self.file_count);
		let callback = Arc::clone(&self.generation_callback);

		let (tx, rx) = unbounded();

		let debouncer =
			new_debouncer(Duration::from_millis(300), None, move |result: notify_debouncer_full::DebounceEventResult| {
				if let Ok(events) = result {
					let _ = tx.send(events);
				}
			})
			.map_err(|e| io::Error::other(format!("Failed to create debouncer: {e}")))?;

		*self.watcher.write() = Some(debouncer);

		std::thread::spawn(move || {
			Self::process_events(rx, index, config, generation, file_count, callback);
		});

		self.watch_directories()?;
		Ok(())
	}

	fn watch_directories(&self) -> io::Result<()> {
		let config = self.config.read();
		let Some(ref mut watcher) = *self.watcher.write() else { return Ok(()) };

		for dir in &config.directories {
			if dir.exists() {
				watcher
					.watch(dir, RecursiveMode::Recursive)
					.map_err(|e| io::Error::other(format!("Failed to watch directory {}: {e}", dir.display())))?;
			}
		}
		drop(config);

		Ok(())
	}

	#[allow(clippy::needless_pass_by_value)]
	fn process_events(
		rx: Receiver<Vec<DebouncedEvent>>,
		index: Arc<RwLock<FxHashMap<CompactString, FileEntry>>>,
		config: Arc<RwLock<FileIndexerConfig>>,
		generation: Arc<AtomicUsize>,
		file_count: Arc<AtomicUsize>,
		callback: Arc<parking_lot::Mutex<Option<GenerationCallback>>>,
	) {
		while let Ok(events) = rx.recv() {
			for event in events {
				Self::handle_event(&event, &index, &config, &generation, &file_count, &callback);
			}
		}
	}

	#[allow(clippy::significant_drop_tightening, clippy::significant_drop_in_scrutinee)]
	fn handle_event(
		event: &DebouncedEvent,
		index: &Arc<RwLock<FxHashMap<CompactString, FileEntry>>>,
		config: &Arc<RwLock<FileIndexerConfig>>,
		generation: &Arc<AtomicUsize>,
		file_count: &Arc<AtomicUsize>,
		callback: &Arc<parking_lot::Mutex<Option<GenerationCallback>>>,
	) {
		let cfg = config.read();

		for path in &event.event.paths {
			match event.event.kind {
				EventKind::Remove(_) => {
					let path_str = path.to_string_lossy();
					let normalized_key = CompactString::new(normalize_path(&path_str));
					let mut idx = index.write();
					if idx.remove(&normalized_key).is_some() {
						file_count.store(idx.len(), Ordering::Relaxed);
						let new_gen = generation.fetch_add(1, Ordering::Relaxed) + 1;
						if let Some(cb) = *callback.lock() {
							cb(new_gen);
						}
					}
				}
				EventKind::Create(_) | EventKind::Modify(_) => {
					if !path.exists() {
						let path_str = path.to_string_lossy();
						let normalized_key = CompactString::new(normalize_path(&path_str));
						let mut idx = index.write();
						if idx.remove(&normalized_key).is_some() {
							file_count.store(idx.len(), Ordering::Relaxed);
							let new_gen = generation.fetch_add(1, Ordering::Relaxed) + 1;
							if let Some(cb) = *callback.lock() {
								cb(new_gen);
							}
						}
						continue;
					}

					if !path.is_file() {
						continue;
					}

					let Some(ext) = path.extension().and_then(|e| e.to_str()) else { continue };
					if !cfg.extensions.iter().any(|allowed| allowed.eq_ignore_ascii_case(ext)) {
						continue;
					}

					if let Ok(entry) = FileEntry::from_path(path) {
						let key = entry.normalized_key();
						let mut idx = index.write();
						let is_new = !idx.contains_key(&key);
						idx.insert(key, entry);
						if is_new {
							file_count.store(idx.len(), Ordering::Relaxed);
						}
						let new_gen = generation.fetch_add(1, Ordering::Relaxed) + 1;
						if let Some(cb) = *callback.lock() {
							cb(new_gen);
						}
					}
				}
				_ => {}
			}
		}
	}

	#[must_use]
	#[allow(clippy::significant_drop_tightening)]
	pub fn refresh_if_needed(&self) -> bool {
		let config = self.config.read();
		if !config.enabled {
			return false;
		}

		if self.needs_initial.load(Ordering::Relaxed) {
			self.needs_initial.store(false, Ordering::Relaxed);
			return self.scan_all_directories();
		}

		let mut needs_rescan = false;
		let mut last_scan = self.last_scan.write();

		for dir in &config.directories {
			if !dir.exists() {
				continue;
			}

			let current_mtime = fs::metadata(dir).and_then(|m| m.modified()).ok();

			match (last_scan.get(dir), current_mtime) {
				(Some(&last), Some(current)) if current > last => {
					needs_rescan = true;
					last_scan.insert(dir.clone(), current);
				}
				(None, Some(current)) => {
					needs_rescan = true;
					last_scan.insert(dir.clone(), current);
				}
				_ => {}
			}
		}

		drop(last_scan);

		if needs_rescan { self.scan_all_directories() } else { false }
	}

	#[allow(clippy::significant_drop_tightening)]
	fn scan_all_directories(&self) -> bool {
		let config = self.config.read();

		if config.directories.len() > 1 {
			use rayon::prelude::*;
			config.directories.par_iter().filter(|dir| dir.exists()).for_each(|dir| {
				Self::scan_directory(dir, &self.index, &config, &self.file_count);
			});
		} else {
			for dir in &config.directories {
				if dir.exists() {
					Self::scan_directory(dir, &self.index, &config, &self.file_count);
				}
			}
		}

		self.generation.fetch_add(1, Ordering::Relaxed);
		let _ = self.save();
		true
	}

	fn scan_directory(
		path: &Path,
		index: &Arc<RwLock<FxHashMap<CompactString, FileEntry>>>,
		config: &FileIndexerConfig,
		file_count: &Arc<AtomicUsize>,
	) {
		let mut stack = Vec::with_capacity(256);
		stack.push((path.to_path_buf(), 0));
		let mut batch = Vec::with_capacity(BATCH_SIZE);

		while let Some((current, depth)) = stack.pop() {
			if depth >= config.max_depth || file_count.load(Ordering::Relaxed) >= config.max_files {
				break;
			}

			let Ok(entries) = fs::read_dir(&current) else { continue };

			for entry in entries.filter_map(Result::ok) {
				let path = entry.path();

				if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
					if name.starts_with('.') && !config.index_hidden {
						continue;
					}
					if config.exclude_dirs.iter().any(|ex| name == ex) {
						continue;
					}
				}

				if path.is_dir() {
					stack.push((path, depth + 1));
				} else if path.is_file()
					&& let Some(ext) = path.extension().and_then(|e| e.to_str())
					&& config.extensions.iter().any(|allowed| allowed.eq_ignore_ascii_case(ext))
					&& let Ok(file_entry) = FileEntry::from_path(&path)
				{
					batch.push(file_entry);

					if batch.len() >= BATCH_SIZE {
						Self::flush_batch(&mut batch, index, file_count);
					}
				}
			}
		}

		if !batch.is_empty() {
			Self::flush_batch(&mut batch, index, file_count);
		}
	}

	fn flush_batch(
		batch: &mut Vec<FileEntry>,
		index: &Arc<RwLock<FxHashMap<CompactString, FileEntry>>>,
		file_count: &Arc<AtomicUsize>,
	) {
		let mut idx = index.write();
		for entry in batch.drain(..) {
			let key = entry.normalized_key();
			idx.insert(key, entry);
		}
		file_count.store(idx.len(), Ordering::Relaxed);
	}

	pub fn save(&self) -> io::Result<()> {
		let entries: Vec<FileEntry> = self.index.read().values().cloned().collect();
		save_to_disk(&self.storage_path, &entries)
	}

	#[allow(clippy::significant_drop_tightening)]
	pub fn start_indexing(&self) {
		let config = self.config.read();
		if !config.enabled {
			return;
		}
		drop(config);

		if self.index.read().is_empty() {
			let index = Arc::clone(&self.index);
			let config = Arc::clone(&self.config);
			let file_count = Arc::clone(&self.file_count);
			let generation = Arc::clone(&self.generation);
			let storage_path = self.storage_path.clone();

			std::thread::spawn(move || {
				let cfg = config.read();
				for dir in &cfg.directories {
					if dir.exists() {
						Self::scan_directory(dir, &index, &cfg, &file_count);
					}
				}
				generation.fetch_add(1, Ordering::Relaxed);
				let entries: Vec<FileEntry> = index.read().values().cloned().collect();
				let _ = save_to_disk(&storage_path, &entries);
			});
		} else {
			self.needs_initial.store(true, Ordering::Relaxed);
		}

		if self.watcher.read().is_none()
			&& let Err(e) = self.start_file_watcher()
		{
			eprintln!("[FileIndexer] Failed to start file watcher: {e}");
		}
	}

	#[must_use]
	pub fn get_all_files(&self) -> Vec<FileEntry> { self.index.read().values().cloned().collect() }

	pub fn map_files<F, T>(&self, f: F) -> Vec<T>
	where
		F: FnMut(&FileEntry) -> Option<T>,
	{
		self.index.read().values().filter_map(f).collect()
	}

	#[must_use]
	pub fn file_count(&self) -> usize { self.file_count.load(Ordering::Relaxed) }

	pub fn update_config(&self, config: FileIndexerConfig) {
		let needs_restart = {
			let old_config = self.config.read();
			old_config.directories != config.directories
		};

		*self.config.write() = config;

		if needs_restart {
			self.stop_file_watcher();
		}

		self.start_indexing();
	}

	pub fn enable(&self) {
		self.config.write().enabled = true;
		self.start_indexing();
	}

	pub fn disable(&self) {
		self.config.write().enabled = false;
		self.stop_file_watcher();
		let _ = self.save();
	}

	fn stop_file_watcher(&self) { *self.watcher.write() = None; }

	#[must_use]
	pub fn is_enabled(&self) -> bool { self.config.read().enabled }

	#[must_use]
	pub fn estimated_memory_bytes(&self) -> usize {
		const AVG_PATH_LEN: usize = 50;
		const AVG_NAME_LEN: usize = 20;
		const COMPACT_STR_OVERHEAD: usize = 24;
		const HASHMAP_ENTRY_OVERHEAD: usize = 32;

		let count = self.file_count();
		count * (AVG_PATH_LEN + AVG_NAME_LEN + (COMPACT_STR_OVERHEAD * 2) + HASHMAP_ENTRY_OVERHEAD)
	}

	#[must_use]
	pub fn generation(&self) -> usize { self.generation.load(Ordering::Relaxed) }
}
