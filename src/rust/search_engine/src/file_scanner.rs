use std::{path::{Path, PathBuf}, sync::Arc, time::SystemTime};

use compact_str::CompactString;
use lru::LruCache;
use parking_lot::Mutex;
use rustc_hash::FxHashMap;
use walkdir::WalkDir;

use crate::indexer::{IndexedItem, ItemType};

const FILE_CACHE_SIZE: usize = 10;
const MAX_DEPTH: usize = 3;
const MAX_FILES_PER_DIR: usize = 100;

static DEFAULT_EXTENSIONS: &[&str] = &[
	"txt", "md", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv", "json", "xml", "html", "css", "js", "ts",
	"py", "rs", "go", "java", "c", "cpp", "h", "hpp", "swift",
];

type FileCache = Mutex<LruCache<Vec<PathBuf>, Arc<Vec<Arc<IndexedItem>>>>>;

pub struct FileScanner {
	cache:            FileCache,
	allowed_exts:     Vec<String>,
	scan_directories: Vec<PathBuf>,
}

impl FileScanner {
	#[must_use]
	pub fn new(directories: Vec<PathBuf>, extensions: Option<Vec<String>>) -> Self {
		let allowed_exts = extensions.unwrap_or_else(|| DEFAULT_EXTENSIONS.iter().map(|s| (*s).to_owned()).collect());

		Self {
			cache: Mutex::new(LruCache::new(unsafe { std::num::NonZeroUsize::new_unchecked(FILE_CACHE_SIZE) })),
			allowed_exts,
			scan_directories: directories,
		}
	}

	pub fn scan(&self) -> Arc<Vec<Arc<IndexedItem>>> {
		let cache_key = self.scan_directories.clone();

		if let Some(cached) = self.cache.lock().get(&cache_key) {
			return Arc::clone(cached);
		}

		let mut files = Vec::with_capacity(MAX_FILES_PER_DIR * self.scan_directories.len());

		for dir in &self.scan_directories {
			if !dir.exists() || !dir.is_dir() {
				continue;
			}

			let dir_files = Self::scan_directory(dir, &self.allowed_exts, MAX_DEPTH, MAX_FILES_PER_DIR);
			files.extend(dir_files);
		}

		let files = Arc::new(files);
		self.cache.lock().put(cache_key, Arc::clone(&files));
		files
	}

	fn scan_directory(dir: &Path, allowed_exts: &[String], max_depth: usize, max_files: usize) -> Vec<Arc<IndexedItem>> {
		WalkDir::new(dir)
			.max_depth(max_depth)
			.follow_links(false)
			.into_iter()
			.filter_map(Result::ok)
			.filter(|e| e.file_type().is_file())
			.filter(|e| {
				e.path()
					.extension()
					.and_then(|ext| ext.to_str())
					.is_some_and(|ext| allowed_exts.iter().any(|a| a.eq_ignore_ascii_case(ext)))
			})
			.take(max_files)
			.filter_map(|entry| {
				let path = entry.path();
				let name = path.file_name()?.to_str()?;
				let full_path = path.to_str()?;

				let modified = entry.metadata().ok()?.modified().ok()?;
				let timestamp = modified.duration_since(SystemTime::UNIX_EPOCH).ok()?.as_secs();

				let mut metadata = FxHashMap::default();
				metadata.insert(CompactString::new("modified"), CompactString::new(timestamp.to_string()));

				Some(Arc::new(IndexedItem {
					id: CompactString::new(full_path),
					name: CompactString::new(name),
					item_type: ItemType::File,
					path: Some(CompactString::new(full_path)),
					metadata,
				}))
			})
			.collect()
	}

	pub fn update_directories(&mut self, directories: Vec<PathBuf>) {
		self.scan_directories = directories;
		self.cache.lock().clear();
	}

	pub fn update_extensions(&mut self, extensions: Vec<String>) {
		self.allowed_exts = extensions;
		self.cache.lock().clear();
	}
}
