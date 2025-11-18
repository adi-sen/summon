use std::{num::NonZeroUsize, path::{Path, PathBuf}, sync::Arc, time::SystemTime};

use compact_str::CompactString;
use lru::LruCache;
use rustc_hash::FxHashMap;
use walkdir::WalkDir;

use crate::indexer::{IndexedItem, ItemType};

const FILE_CACHE_SIZE: usize = 10;
const FILE_CACHE_SIZE_NZ: NonZeroUsize = NonZeroUsize::new(FILE_CACHE_SIZE).unwrap();
const MAX_DEPTH: usize = 3;
const MAX_FILES_PER_DIR: usize = 100;

static DEFAULT_EXTENSIONS: &[&str] = &[
	"txt", "md", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv", "json", "xml", "html", "css", "js", "ts",
	"py", "rs", "go", "java", "c", "cpp", "h", "hpp", "swift",
];

#[allow(clippy::rc_buffer)]
pub struct FileScanner {
	cache:            LruCache<Arc<Vec<PathBuf>>, Arc<Vec<IndexedItem>>>,
	allowed_exts:     Vec<String>,
	scan_directories: Arc<Vec<PathBuf>>,
}

impl FileScanner {
	#[must_use]
	pub fn new(directories: Vec<PathBuf>, extensions: Option<Vec<String>>) -> Self {
		let allowed_exts = extensions.unwrap_or_else(|| DEFAULT_EXTENSIONS.iter().map(|&s| s.into()).collect());

		Self { cache: LruCache::new(FILE_CACHE_SIZE_NZ), allowed_exts, scan_directories: Arc::new(directories) }
	}

	pub fn scan(&mut self) -> Arc<Vec<IndexedItem>> {
		if let Some(cached) = self.cache.get(&self.scan_directories) {
			return Arc::clone(cached);
		}

		let mut files = Vec::with_capacity(MAX_FILES_PER_DIR * self.scan_directories.len());

		for dir in self.scan_directories.iter() {
			if !dir.exists() || !dir.is_dir() {
				continue;
			}

			let dir_files = Self::scan_directory(dir, &self.allowed_exts, MAX_DEPTH, MAX_FILES_PER_DIR);
			files.extend(dir_files);
		}

		let arc_files = Arc::new(files);
		self.cache.put(Arc::clone(&self.scan_directories), Arc::clone(&arc_files));
		arc_files
	}

	fn scan_directory(dir: &Path, allowed_exts: &[String], max_depth: usize, max_files: usize) -> Vec<IndexedItem> {
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
				metadata.insert(CompactString::new("modified"), CompactString::from(timestamp.to_string()));

				let path_compact = CompactString::new(full_path);

				Some(IndexedItem {
					id:        path_compact.clone(),
					name:      CompactString::new(name),
					item_type: ItemType::File,
					path:      Some(path_compact),
					metadata:  Some(metadata),
				})
			})
			.collect()
	}

	pub fn update_directories(&mut self, directories: Vec<PathBuf>) {
		self.scan_directories = Arc::new(directories);
		self.cache.clear();
	}

	pub fn update_extensions(&mut self, extensions: Vec<String>) {
		self.allowed_exts = extensions;
		self.cache.clear();
	}
}
