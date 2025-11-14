#![allow(clippy::missing_safety_doc)]
#![allow(clippy::missing_panics_doc)]
#![allow(clippy::ptr_as_ptr)]
#![allow(clippy::redundant_closure_for_method_calls)]
#![allow(clippy::option_if_let_else)]
#![allow(clippy::single_match_else)]
#![allow(clippy::map_unwrap_or)]
#![allow(clippy::manual_let_else)]

use std::{ffi::{CStr, CString}, ptr, sync::Arc};

use action_manager::{ActionManager, action::{Action, PatternActionType, ResultAction}};
use app_storage::{AppEntry, AppStorage};
use calculator::Calculator;
use clipboard_storage::{ClipboardEntry, ClipboardStorage};
use compact_str::CompactString;
use libc::{c_char, size_t};
use parking_lot::Mutex;
use rustc_hash::FxHashMap;
use search_engine::{SearchEngine, indexer::{IndexedItem, ItemType}};
use settings_storage::{AppSettings, SettingsStorage};
use snippet_matcher::{Snippet, SnippetMatcher};
use snippet_storage::SnippetStorage;
use sonic_rs::{JsonContainerTrait, JsonValueTrait};

/// cbindgen:ignore
#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;

macro_rules! cstr {
	($ptr:expr) => {{
		#[allow(unused_unsafe)]
		if $ptr.is_null() { "" } else { unsafe { CStr::from_ptr($ptr).to_str().unwrap_or("") } }
	}};
}

macro_rules! opt_string {
	($ptr:expr) => {{
		#[allow(unused_unsafe)]
		if $ptr.is_null() { None } else { unsafe { CStr::from_ptr($ptr).to_str().ok().map(|s| s.to_string()) } }
	}};
}

macro_rules! require_handle {
	($handle:expr) => {
		if $handle.is_null() {
			return false;
		}
	};
	($handle:expr, $($ptr:expr),+) => {
		if $handle.is_null() $(|| $ptr.is_null())+ {
			return false;
		}
	};
}

macro_rules! require_handle_ptr {
	($handle:expr) => {
		if $handle.is_null() {
			return ptr::null_mut();
		}
	};
	($handle:expr, $($ptr:expr),+) => {
		if $handle.is_null() $(|| $ptr.is_null())+ {
			return ptr::null_mut();
		}
	};
}

#[allow(dead_code)]
fn to_cstring_ptr(s: impl Into<Vec<u8>>) -> *mut c_char {
	CString::new(s).ok().map(CString::into_raw).unwrap_or(ptr::null_mut())
}

#[allow(dead_code)]
fn optional_cstring(s: Option<String>) -> *mut c_char {
	s.and_then(|s| CString::new(s).ok()).map(CString::into_raw).unwrap_or(ptr::null_mut())
}

macro_rules! storage_handle {
	($name:ident, $inner:ty, $prefix:ident) => {
		paste::paste! {
			#[unsafe(no_mangle)]
			pub unsafe extern "C" fn [<$prefix _new>](path: *const c_char) -> *mut $name {
				if path.is_null() {
					return ptr::null_mut();
				}
				<$inner>::new(cstr!(path)).ok().map(|inner| Box::into_raw(Box::new($name { inner: Arc::new(inner) }))).unwrap_or(ptr::null_mut())
			}

			#[unsafe(no_mangle)]
			pub unsafe extern "C" fn [<$prefix _free>](handle: *mut $name) {
				if !handle.is_null() {
					unsafe { drop(Box::from_raw(handle)) };
				}
			}
		}
	};
}

pub struct SearchEngineHandle {
	engine: Arc<Mutex<SearchEngine>>,
}

#[repr(C)]
pub struct CSearchResult {
	pub id:    *mut c_char,
	pub name:  *mut c_char,
	pub path:  *mut c_char,
	pub score: i64,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_new() -> *mut SearchEngineHandle {
	Box::into_raw(Box::new(SearchEngineHandle { engine: Arc::new(Mutex::new(SearchEngine::new())) }))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_free(handle: *mut SearchEngineHandle) {
	if !handle.is_null() {
		unsafe { drop(Box::from_raw(handle)) };
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_add_item(
	handle: *mut SearchEngineHandle,
	id: *const c_char,
	name: *const c_char,
	path: *const c_char,
	item_type: u8,
) -> bool {
	if handle.is_null() {
		return false;
	}
	let item_type = match item_type {
		0 => ItemType::Application,
		1 => ItemType::File,
		4 => ItemType::Custom("Command".to_owned()),
		_ => return false,
	};
	let item = IndexedItem {
		id: CompactString::new(cstr!(id)),
		name: CompactString::new(cstr!(name)),
		item_type,
		path: Some(CompactString::new(cstr!(path))),
		metadata: FxHashMap::default(),
	};
	unsafe {
		(*handle).engine.lock().indexer().write().add_item(item);
		(*handle).engine.lock().clear_cache();
	}
	true
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_search(
	handle: *mut SearchEngineHandle,
	query: *const c_char,
	limit: size_t,
	out_count: *mut size_t,
) -> *mut CSearchResult {
	if handle.is_null() || query.is_null() || out_count.is_null() {
		return ptr::null_mut();
	}

	let results = match unsafe { (*handle).engine.lock().search(cstr!(query), limit) } {
		Ok(results) => results,
		Err(_) => {
			unsafe { *out_count = 0 };
			return ptr::null_mut();
		}
	};

	if results.is_empty() {
		unsafe { *out_count = 0 };
		return ptr::null_mut();
	}

	let c_results: Vec<CSearchResult> = results
		.into_iter()
		.map(|r| CSearchResult {
			id:    to_cstring_ptr(r.item.id.as_str()),
			name:  to_cstring_ptr(r.item.name.as_str()),
			path:  r
				.item
				.path
				.clone()
				.and_then(|p| CString::new(p.as_str()).ok())
				.map(CString::into_raw)
				.unwrap_or(ptr::null_mut()),
			score: r.score,
		})
		.collect();

	unsafe { *out_count = c_results.len() };
	Box::into_raw(c_results.into_boxed_slice()) as *mut CSearchResult
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_results_free(results: *mut CSearchResult, count: size_t) {
	if results.is_null() || count == 0 {
		return;
	}
	unsafe {
		for i in 0..count {
			let result = &(*results.add(i));
			if !result.id.is_null() {
				drop(CString::from_raw(result.id));
			}
			if !result.name.is_null() {
				drop(CString::from_raw(result.name));
			}
			if !result.path.is_null() {
				drop(CString::from_raw(result.path));
			}
		}
		drop(Vec::from_raw_parts(results, count, count));
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_stats(
	handle: *mut SearchEngineHandle,
	total: *mut size_t,
	apps: *mut size_t,
	files: *mut size_t,
	snippets: *mut size_t,
) -> bool {
	if handle.is_null() {
		return false;
	}
	let (total_count, apps_count, files_count, snippets_count) =
		unsafe { (*handle).engine.lock().indexer().read().stats() };
	if !total.is_null() {
		unsafe { *total = total_count };
	}
	if !apps.is_null() {
		unsafe { *apps = apps_count };
	}
	if !files.is_null() {
		unsafe { *files = files_count };
	}
	if !snippets.is_null() {
		unsafe { *snippets = snippets_count };
	}
	true
}

#[repr(C)]
pub struct CStringArray {
	pub data: *mut *mut c_char,
	pub len:  size_t,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_scan_apps(
	handle: *mut SearchEngineHandle,
	directories: CStringArray,
	exclude_patterns: CStringArray,
) -> size_t {
	if handle.is_null() || directories.data.is_null() {
		return 0;
	}

	let dirs: Vec<&str> = unsafe {
		std::slice::from_raw_parts(directories.data, directories.len)
			.iter()
			.filter_map(|&ptr| if ptr.is_null() { None } else { CStr::from_ptr(ptr).to_str().ok() })
			.collect()
	};

	let excludes: Vec<&str> = if exclude_patterns.data.is_null() {
		vec![]
	} else {
		unsafe {
			std::slice::from_raw_parts(exclude_patterns.data, exclude_patterns.len)
				.iter()
				.filter_map(|&ptr| if ptr.is_null() { None } else { CStr::from_ptr(ptr).to_str().ok() })
				.collect()
		}
	};

	let engine = unsafe { &(*handle).engine };

	let mut new_apps = Vec::new();
	{
		let lock = engine.lock();
		let indexer = lock.indexer();
		let reader = indexer.read();

		for dir in &dirs {
			let Ok(entries) = std::fs::read_dir(dir) else {
				continue;
			};

			for entry in entries.flatten() {
				let path = entry.path();

				if path.extension().and_then(|s| s.to_str()) != Some("app") {
					continue;
				}

				let Some(name) = path.file_stem().and_then(|s| s.to_str()) else {
					continue;
				};

				let name_lower = name.to_lowercase();
				if excludes.iter().any(|pattern| name_lower.contains(pattern)) {
					continue;
				}

				let Some(full_path) = path.to_str() else {
					continue;
				};

				if reader.get_item(full_path).is_none() {
					new_apps.push((full_path.to_string(), name.to_string()));
				}
			}
		}
	}

	let added_count = new_apps.len();
	if !new_apps.is_empty() {
		let items: Vec<IndexedItem> = new_apps
			.into_iter()
			.map(|(full_path, name)| IndexedItem {
				id:        CompactString::new(&full_path),
				name:      CompactString::new(&name),
				item_type: ItemType::Application,
				path:      Some(CompactString::new(&full_path)),
				metadata:  FxHashMap::default(),
			})
			.collect();

		let lock = engine.lock();
		lock.indexer().write().add_items(items);
		lock.clear_cache();
	}

	added_count
}

#[repr(C)]
pub struct CIndexedApp {
	pub name: *mut c_char,
	pub path: *mut c_char,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_get_apps(
	handle: *mut SearchEngineHandle,
	out_count: *mut size_t,
) -> *mut CIndexedApp {
	if handle.is_null() || out_count.is_null() {
		return ptr::null_mut();
	}

	let apps = {
		let engine = unsafe { &(*handle).engine };
		let lock = engine.lock();
		let indexer = lock.indexer();
		let reader = indexer.read();
		reader
			.get_items_by_type(&search_engine::indexer::ItemType::Application)
			.iter()
			.map(|item| (item.name.to_string(), item.path.as_ref().map(|p| p.to_string()).unwrap_or_default()))
			.collect::<Vec<_>>()
	};

	if apps.is_empty() {
		unsafe { *out_count = 0 };
		return ptr::null_mut();
	}

	let c_apps: Vec<CIndexedApp> = apps
		.into_iter()
		.map(|(name, path)| CIndexedApp { name: to_cstring_ptr(name), path: to_cstring_ptr(path) })
		.collect();

	unsafe { *out_count = c_apps.len() };
	Box::into_raw(c_apps.into_boxed_slice()) as *mut CIndexedApp
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn indexed_apps_free(entries: *mut CIndexedApp, count: size_t) {
	if entries.is_null() || count == 0 {
		return;
	}
	unsafe {
		for i in 0..count {
			let entry = &(*entries.add(i));
			if !entry.name.is_null() {
				drop(CString::from_raw(entry.name));
			}
			if !entry.path.is_null() {
				drop(CString::from_raw(entry.path));
			}
		}
		drop(Vec::from_raw_parts(entries, count, count));
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_enable_file_search(
	handle: *mut SearchEngineHandle,
	directories: CStringArray,
	extensions: CStringArray,
) -> bool {
	if handle.is_null() || directories.data.is_null() {
		return false;
	}

	let dirs: Vec<std::path::PathBuf> = unsafe {
		std::slice::from_raw_parts(directories.data, directories.len)
			.iter()
			.filter_map(
				|&ptr| {
					if ptr.is_null() { None } else { CStr::from_ptr(ptr).to_str().ok().map(std::path::PathBuf::from) }
				},
			)
			.collect()
	};

	let exts: Option<Vec<String>> = if extensions.data.is_null() {
		None
	} else {
		Some(unsafe {
			std::slice::from_raw_parts(extensions.data, extensions.len)
				.iter()
				.filter_map(|&ptr| if ptr.is_null() { None } else { CStr::from_ptr(ptr).to_str().ok().map(String::from) })
				.collect()
		})
	};

	let engine = unsafe { &(*handle).engine };
	engine.lock().enable_file_search(dirs, exts);
	true
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_disable_file_search(handle: *mut SearchEngineHandle) -> bool {
	if handle.is_null() {
		return false;
	}
	let engine = unsafe { &(*handle).engine };
	engine.lock().disable_file_search();
	true
}

pub struct CalculatorHandle {
	calc: std::cell::RefCell<Calculator>,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn calculator_new() -> *mut CalculatorHandle {
	Box::into_raw(Box::new(CalculatorHandle { calc: std::cell::RefCell::new(Calculator::new()) }))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn calculator_free(handle: *mut CalculatorHandle) {
	if !handle.is_null() {
		unsafe { drop(Box::from_raw(handle)) };
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn calculator_evaluate(handle: *mut CalculatorHandle, expr: *const c_char) -> *mut c_char {
	if handle.is_null() || expr.is_null() {
		return ptr::null_mut();
	}
	match unsafe { (*handle).calc.borrow_mut().evaluate(cstr!(expr)) } {
		Some(result) => to_cstring_ptr(result),
		None => ptr::null_mut(),
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn calculator_get_history_json(handle: *mut CalculatorHandle) -> *mut c_char {
	if handle.is_null() {
		return ptr::null_mut();
	}
	let history_vec: Vec<_> = unsafe { (*handle).calc.borrow().get_history().iter().cloned().collect() };
	let json_entries: Vec<_> =
		history_vec.iter().map(|e| sonic_rs::json!({"query": e.query, "result": e.result})).collect();
	match sonic_rs::to_string(&json_entries) {
		Ok(json) => to_cstring_ptr(json),
		Err(_) => ptr::null_mut(),
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn calculator_free_string(s: *mut c_char) {
	if !s.is_null() {
		unsafe { drop(CString::from_raw(s)) };
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn calculator_clear_history(handle: *mut CalculatorHandle) {
	if !handle.is_null() {
		unsafe { (*handle).calc.borrow_mut().clear_history() };
	}
}

pub struct ClipboardStorageHandle {
	inner: Arc<ClipboardStorage>,
}

storage_handle!(ClipboardStorageHandle, ClipboardStorage, clipboard_storage);

#[repr(C)]
pub struct CClipboardEntry {
	pub content:         *mut c_char,
	pub timestamp:       f64,
	pub item_type:       u8,
	pub image_file_path: *mut c_char,
	pub image_width:     f64,
	pub image_height:    f64,
	pub size:            i32,
	pub source_app:      *mut c_char,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn clipboard_storage_add_text(
	handle: *mut ClipboardStorageHandle,
	content: *const c_char,
	timestamp: f64,
	size: i32,
	source_app: *const c_char,
) -> bool {
	require_handle!(handle, content);
	let entry = ClipboardEntry::new_text(cstr!(content).to_string(), timestamp, size, opt_string!(source_app));
	unsafe { (*handle).inner.add_entry(entry).is_ok() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn clipboard_storage_add_image(
	handle: *mut ClipboardStorageHandle,
	content: *const c_char,
	timestamp: f64,
	image_file_path: *const c_char,
	width: f64,
	height: f64,
	size: i32,
	source_app: *const c_char,
) -> bool {
	require_handle!(handle, content, image_file_path);
	let entry = ClipboardEntry::new_image(
		cstr!(content).to_string(),
		timestamp,
		cstr!(image_file_path).to_string(),
		width,
		height,
		size,
		opt_string!(source_app),
	);
	unsafe { (*handle).inner.add_entry(entry).is_ok() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn clipboard_storage_get_entries(
	handle: *mut ClipboardStorageHandle,
	start: size_t,
	count: size_t,
	out_count: *mut size_t,
) -> *mut CClipboardEntry {
	require_handle_ptr!(handle, out_count);

	let entries = unsafe { (*handle).inner.get_entries_range(start, count) };

	if entries.is_empty() {
		unsafe { *out_count = 0 };
		return ptr::null_mut();
	}

	let c_entries: Vec<CClipboardEntry> = entries
		.into_iter()
		.map(|e| {
			let (width, height) = e.image_size.map(|s| (s.width, s.height)).unwrap_or((0.0, 0.0));
			CClipboardEntry {
				content:         to_cstring_ptr(e.content),
				timestamp:       e.timestamp,
				item_type:       e.item_type.as_u8(),
				image_file_path: e
					.image_file_path
					.and_then(|p| CString::new(p).ok())
					.map(CString::into_raw)
					.unwrap_or(ptr::null_mut()),
				image_width:     width,
				image_height:    height,
				size:            e.size,
				source_app:      e
					.source_app
					.and_then(|s| CString::new(s).ok())
					.map(CString::into_raw)
					.unwrap_or(ptr::null_mut()),
			}
		})
		.collect();

	unsafe { *out_count = c_entries.len() };
	Box::into_raw(c_entries.into_boxed_slice()) as *mut CClipboardEntry
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn clipboard_entries_free(entries: *mut CClipboardEntry, count: size_t) {
	if entries.is_null() || count == 0 {
		return;
	}
	unsafe {
		for i in 0..count {
			let entry = &(*entries.add(i));
			if !entry.content.is_null() {
				drop(CString::from_raw(entry.content));
			}
			if !entry.image_file_path.is_null() {
				drop(CString::from_raw(entry.image_file_path));
			}
			if !entry.source_app.is_null() {
				drop(CString::from_raw(entry.source_app));
			}
		}
		drop(Vec::from_raw_parts(entries, count, count));
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn clipboard_storage_len(handle: *mut ClipboardStorageHandle) -> size_t {
	if handle.is_null() {
		return 0;
	}
	unsafe { (*handle).inner.len() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn clipboard_storage_trim(handle: *mut ClipboardStorageHandle, max: size_t) -> bool {
	if handle.is_null() {
		return false;
	}
	unsafe { (*handle).inner.trim_to(max).is_ok() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn clipboard_storage_clear(handle: *mut ClipboardStorageHandle) -> bool {
	if handle.is_null() {
		return false;
	}
	unsafe { (*handle).inner.clear().is_ok() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn clipboard_storage_remove_at(handle: *mut ClipboardStorageHandle, index: size_t) -> bool {
	if handle.is_null() {
		return false;
	}
	unsafe { (*handle).inner.remove_at(index).unwrap_or(false) }
}

pub struct SnippetMatcherHandle {
	matcher: Arc<SnippetMatcher>,
}

#[repr(C)]
pub struct CSnippetMatch {
	pub trigger: *mut c_char,
	pub content: *mut c_char,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_matcher_new() -> *mut SnippetMatcherHandle {
	Box::into_raw(Box::new(SnippetMatcherHandle { matcher: Arc::new(SnippetMatcher::new()) }))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_matcher_free(handle: *mut SnippetMatcherHandle) {
	if !handle.is_null() {
		unsafe { drop(Box::from_raw(handle)) };
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_matcher_update(handle: *mut SnippetMatcherHandle, json: *const c_char) -> bool {
	if handle.is_null() || json.is_null() {
		return false;
	}
	match sonic_rs::from_str::<Vec<Snippet>>(cstr!(json)) {
		Ok(snippets) => {
			unsafe { (*handle).matcher.update_snippets(snippets) };
			true
		}
		Err(_) => false,
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_matcher_find(
	handle: *mut SnippetMatcherHandle,
	text: *const c_char,
) -> *mut CSnippetMatch {
	if handle.is_null() || text.is_null() {
		return ptr::null_mut();
	}
	match unsafe { (*handle).matcher.find_match(cstr!(text)) } {
		Some((trigger, content, _)) => {
			Box::into_raw(Box::new(CSnippetMatch { trigger: to_cstring_ptr(trigger), content: to_cstring_ptr(content) }))
		}
		None => ptr::null_mut(),
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_match_free(result: *mut CSnippetMatch) {
	if !result.is_null() {
		unsafe {
			if !(*result).trigger.is_null() {
				drop(CString::from_raw((*result).trigger));
			}
			if !(*result).content.is_null() {
				drop(CString::from_raw((*result).content));
			}
			drop(Box::from_raw(result));
		}
	}
}

pub struct SnippetStorageHandle {
	inner: Arc<SnippetStorage>,
}

storage_handle!(SnippetStorageHandle, SnippetStorage, snippet_storage);

#[repr(C)]
pub struct CSnippet {
	pub id:       *mut c_char,
	pub trigger:  *mut c_char,
	pub content:  *mut c_char,
	pub enabled:  bool,
	pub category: *mut c_char,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_storage_add(
	handle: *mut SnippetStorageHandle,
	id: *const c_char,
	trigger: *const c_char,
	content: *const c_char,
	enabled: bool,
	category: *const c_char,
) -> bool {
	if handle.is_null() {
		return false;
	}
	let snippet = snippet_storage::Snippet {
		id: cstr!(id).to_string(),
		trigger: cstr!(trigger).to_string(),
		content: cstr!(content).to_string(),
		enabled,
		category: cstr!(category).to_string(),
	};
	unsafe { (*handle).inner.add(snippet).is_ok() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_storage_update(
	handle: *mut SnippetStorageHandle,
	id: *const c_char,
	trigger: *const c_char,
	content: *const c_char,
	enabled: bool,
	category: *const c_char,
) -> bool {
	if handle.is_null() {
		return false;
	}
	let snippet = snippet_storage::Snippet {
		id: cstr!(id).to_string(),
		trigger: cstr!(trigger).to_string(),
		content: cstr!(content).to_string(),
		enabled,
		category: cstr!(category).to_string(),
	};
	unsafe { (*handle).inner.update(snippet).is_ok() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_storage_delete(handle: *mut SnippetStorageHandle, id: *const c_char) -> bool {
	if handle.is_null() || id.is_null() {
		return false;
	}
	unsafe { (*handle).inner.delete(cstr!(id)).is_ok() }
}

fn snippets_to_c(snippets: Vec<snippet_storage::Snippet>) -> (*mut CSnippet, size_t) {
	if snippets.is_empty() {
		return (ptr::null_mut(), 0);
	}

	let c_snippets: Vec<CSnippet> = snippets
		.into_iter()
		.map(|s| CSnippet {
			id:       to_cstring_ptr(s.id),
			trigger:  to_cstring_ptr(s.trigger),
			content:  to_cstring_ptr(s.content),
			enabled:  s.enabled,
			category: to_cstring_ptr(s.category),
		})
		.collect();

	let count = c_snippets.len();
	(Box::into_raw(c_snippets.into_boxed_slice()) as *mut CSnippet, count)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_storage_get_all(
	handle: *mut SnippetStorageHandle,
	out_count: *mut size_t,
) -> *mut CSnippet {
	if handle.is_null() || out_count.is_null() {
		return ptr::null_mut();
	}
	let (ptr, count) = snippets_to_c(unsafe { (*handle).inner.get_all() });
	unsafe { *out_count = count };
	ptr
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_storage_get_enabled(
	handle: *mut SnippetStorageHandle,
	out_count: *mut size_t,
) -> *mut CSnippet {
	if handle.is_null() || out_count.is_null() {
		return ptr::null_mut();
	}
	let (ptr, count) = snippets_to_c(unsafe { (*handle).inner.get_enabled() });
	unsafe { *out_count = count };
	ptr
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippets_free(snippets: *mut CSnippet, count: size_t) {
	if snippets.is_null() || count == 0 {
		return;
	}
	unsafe {
		for i in 0..count {
			let snippet = &(*snippets.add(i));
			if !snippet.id.is_null() {
				drop(CString::from_raw(snippet.id));
			}
			if !snippet.trigger.is_null() {
				drop(CString::from_raw(snippet.trigger));
			}
			if !snippet.content.is_null() {
				drop(CString::from_raw(snippet.content));
			}
			if !snippet.category.is_null() {
				drop(CString::from_raw(snippet.category));
			}
		}
		drop(Vec::from_raw_parts(snippets, count, count));
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_storage_len(handle: *mut SnippetStorageHandle) -> size_t {
	if handle.is_null() {
		return 0;
	}
	unsafe { (*handle).inner.len() }
}

pub struct AppStorageHandle {
	inner: Arc<AppStorage>,
}

storage_handle!(AppStorageHandle, AppStorage, app_storage);

#[repr(C)]
pub struct CAppEntry {
	pub name: *mut c_char,
	pub path: *mut c_char,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn app_storage_add(
	handle: *mut AppStorageHandle,
	name: *const c_char,
	path: *const c_char,
) -> bool {
	if handle.is_null() || name.is_null() || path.is_null() {
		return false;
	}
	let entry = AppEntry::new(cstr!(name).to_string(), cstr!(path).to_string());
	unsafe { (*handle).inner.add_entry(entry).is_ok() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn app_storage_get_all(handle: *mut AppStorageHandle, out_count: *mut size_t) -> *mut CAppEntry {
	if handle.is_null() || out_count.is_null() {
		return ptr::null_mut();
	}

	let entries = unsafe { (*handle).inner.get_entries() };

	if entries.is_empty() {
		unsafe { *out_count = 0 };
		return ptr::null_mut();
	}

	let c_entries: Vec<CAppEntry> =
		entries.into_iter().map(|e| CAppEntry { name: to_cstring_ptr(e.name), path: to_cstring_ptr(e.path) }).collect();

	unsafe { *out_count = c_entries.len() };
	Box::into_raw(c_entries.into_boxed_slice()) as *mut CAppEntry
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn app_entries_free(entries: *mut CAppEntry, count: size_t) {
	if entries.is_null() || count == 0 {
		return;
	}
	unsafe {
		for i in 0..count {
			let entry = &(*entries.add(i));
			if !entry.name.is_null() {
				drop(CString::from_raw(entry.name));
			}
			if !entry.path.is_null() {
				drop(CString::from_raw(entry.path));
			}
		}
		drop(Vec::from_raw_parts(entries, count, count));
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn app_storage_len(handle: *mut AppStorageHandle) -> size_t {
	if handle.is_null() {
		return 0;
	}
	unsafe { (*handle).inner.len() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn app_storage_clear(handle: *mut AppStorageHandle) -> bool {
	if handle.is_null() {
		return false;
	}
	unsafe { (*handle).inner.clear().is_ok() }
}

pub struct SettingsStorageHandle {
	inner: Arc<SettingsStorage>,
}

storage_handle!(SettingsStorageHandle, SettingsStorage, settings_storage);

#[repr(C)]
pub struct CAppSettings {
	pub theme:                    *mut c_char,
	pub custom_font_name:         *mut c_char,
	pub font_size:                *mut c_char,
	pub max_results:              i32,
	pub max_clipboard_items:      i32,
	pub clipboard_retention_days: i32,
	pub quick_select_modifier:    *mut c_char,
	pub enable_commands:          bool,
	pub show_tray_icon:           bool,
	pub show_dock_icon:           bool,
	pub hide_traffic_lights:      bool,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn settings_storage_get(handle: *mut SettingsStorageHandle) -> *mut CAppSettings {
	if handle.is_null() {
		return ptr::null_mut();
	}

	let settings = unsafe { (*handle).inner.get() };

	Box::into_raw(Box::new(CAppSettings {
		theme:                    to_cstring_ptr(settings.theme),
		custom_font_name:         to_cstring_ptr(settings.custom_font_name),
		font_size:                to_cstring_ptr(settings.font_size),
		max_results:              settings.max_results,
		max_clipboard_items:      settings.max_clipboard_items,
		clipboard_retention_days: settings.clipboard_retention_days,
		quick_select_modifier:    to_cstring_ptr(settings.quick_select_modifier),
		enable_commands:          settings.enable_commands,
		show_tray_icon:           settings.show_tray_icon,
		show_dock_icon:           settings.show_dock_icon,
		hide_traffic_lights:      settings.hide_traffic_lights,
	}))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn settings_storage_save(
	handle: *mut SettingsStorageHandle,
	theme: *const c_char,
	custom_font_name: *const c_char,
	font_size: *const c_char,
	max_results: i32,
	max_clipboard_items: i32,
	clipboard_retention_days: i32,
	quick_select_modifier: *const c_char,
	enable_commands: bool,
	show_tray_icon: bool,
	show_dock_icon: bool,
	hide_traffic_lights: bool,
	search_folders_json: *const c_char,
	launcher_shortcut_json: *const c_char,
	clipboard_shortcut_json: *const c_char,
) -> bool {
	if handle.is_null() {
		return false;
	}

	let search_folders: Vec<String> = if search_folders_json.is_null() {
		vec![]
	} else {
		sonic_rs::from_str(cstr!(search_folders_json)).unwrap_or_default()
	};

	let launcher_shortcut: sonic_rs::Value = if launcher_shortcut_json.is_null() {
		sonic_rs::json!({"key": "space", "modifiers": ["command"]})
	} else {
		sonic_rs::from_str(cstr!(launcher_shortcut_json)).unwrap_or(sonic_rs::json!({}))
	};

	let clipboard_shortcut: sonic_rs::Value = if clipboard_shortcut_json.is_null() {
		sonic_rs::json!({"key": "v", "modifiers": ["command", "shift"]})
	} else {
		sonic_rs::from_str(cstr!(clipboard_shortcut_json)).unwrap_or(sonic_rs::json!({}))
	};

	let launcher_key = launcher_shortcut["key"].as_str().unwrap_or("space").to_owned();
	let launcher_mods: Vec<String> = launcher_shortcut["modifiers"]
		.as_array()
		.map(|arr| arr.iter().filter_map(|v| v.as_str().map(|s| s.to_owned())).collect())
		.unwrap_or_default();

	let clipboard_key = clipboard_shortcut["key"].as_str().unwrap_or("v").to_owned();
	let clipboard_mods: Vec<String> = clipboard_shortcut["modifiers"]
		.as_array()
		.map(|arr| arr.iter().filter_map(|v| v.as_str().map(|s| s.to_owned())).collect())
		.unwrap_or_default();

	let settings = AppSettings {
		theme: cstr!(theme).to_string(),
		custom_font_name: cstr!(custom_font_name).to_string(),
		font_size: cstr!(font_size).to_string(),
		max_results,
		max_clipboard_items,
		clipboard_retention_days,
		quick_select_modifier: cstr!(quick_select_modifier).to_string(),
		enable_commands,
		show_tray_icon,
		show_dock_icon,
		hide_traffic_lights,
		launcher_shortcut_key: launcher_key,
		launcher_shortcut_mods: launcher_mods,
		clipboard_shortcut_key: clipboard_key,
		clipboard_shortcut_mods: clipboard_mods,
		search_folders,
	};

	unsafe { (*handle).inner.save(settings).is_ok() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn settings_free(settings: *mut CAppSettings) {
	if settings.is_null() {
		return;
	}
	unsafe {
		let settings = Box::from_raw(settings);
		if !settings.theme.is_null() {
			drop(CString::from_raw(settings.theme));
		}
		if !settings.custom_font_name.is_null() {
			drop(CString::from_raw(settings.custom_font_name));
		}
		if !settings.font_size.is_null() {
			drop(CString::from_raw(settings.font_size));
		}
		if !settings.quick_select_modifier.is_null() {
			drop(CString::from_raw(settings.quick_select_modifier));
		}
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn settings_storage_get_search_folders(handle: *mut SettingsStorageHandle) -> *mut c_char {
	if handle.is_null() {
		return ptr::null_mut();
	}
	let settings = unsafe { (*handle).inner.get() };
	let json = sonic_rs::to_string(&settings.search_folders).unwrap_or_else(|_| "[]".to_owned());
	to_cstring_ptr(json)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn settings_storage_get_launcher_shortcut(handle: *mut SettingsStorageHandle) -> *mut c_char {
	if handle.is_null() {
		return ptr::null_mut();
	}
	let settings = unsafe { (*handle).inner.get() };
	let Ok(json) = sonic_rs::to_string(&sonic_rs::json!({
		"key": settings.launcher_shortcut_key,
		"modifiers": settings.launcher_shortcut_mods
	})) else {
		return ptr::null_mut();
	};
	to_cstring_ptr(json)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn settings_storage_get_clipboard_shortcut(handle: *mut SettingsStorageHandle) -> *mut c_char {
	if handle.is_null() {
		return ptr::null_mut();
	}
	let settings = unsafe { (*handle).inner.get() };
	let Ok(json) = sonic_rs::to_string(&sonic_rs::json!({
		"key": settings.clipboard_shortcut_key,
		"modifiers": settings.clipboard_shortcut_mods
	})) else {
		return ptr::null_mut();
	};
	to_cstring_ptr(json)
}

pub struct ActionManagerHandle {
	manager: ActionManager,
}

#[repr(C)]
pub struct CActionResult {
	pub id:       *mut c_char,
	pub title:    *mut c_char,
	pub subtitle: *mut c_char,
	pub icon:     *mut c_char,
	pub url:      *mut c_char,
	pub score:    f32,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_manager_new(path: *const c_char) -> *mut ActionManagerHandle {
	if path.is_null() {
		return ptr::null_mut();
	}

	match ActionManager::new(cstr!(path)) {
		Ok(manager) => Box::into_raw(Box::new(ActionManagerHandle { manager })),
		Err(_) => ptr::null_mut(),
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_manager_free(handle: *mut ActionManagerHandle) {
	if !handle.is_null() {
		unsafe { drop(Box::from_raw(handle)) };
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_manager_search(
	handle: *mut ActionManagerHandle,
	query: *const c_char,
	out_count: *mut size_t,
) -> *mut CActionResult {
	if handle.is_null() || query.is_null() || out_count.is_null() {
		return ptr::null_mut();
	}

	let results = unsafe { (*handle).manager.search(cstr!(query)) };

	if results.is_empty() {
		unsafe { *out_count = 0 };
		return ptr::null_mut();
	}

	let c_results: Vec<CActionResult> = results
		.into_iter()
		.map(|r| {
			let url = match r.action {
				ResultAction::OpenUrl(url) => to_cstring_ptr(url),
				ResultAction::CopyText(text) => to_cstring_ptr(text),
				ResultAction::RunCommand { cmd, .. } => to_cstring_ptr(cmd),
			};

			CActionResult {
				id: to_cstring_ptr(r.id),
				title: to_cstring_ptr(r.title),
				subtitle: to_cstring_ptr(r.subtitle),
				icon: to_cstring_ptr(r.icon),
				url,
				score: r.score,
			}
		})
		.collect();

	unsafe { *out_count = c_results.len() };
	Box::into_raw(c_results.into_boxed_slice()) as *mut CActionResult
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_results_free(results: *mut CActionResult, count: size_t) {
	if results.is_null() || count == 0 {
		return;
	}

	unsafe {
		for i in 0..count {
			let result = &(*results.add(i));
			if !result.id.is_null() {
				drop(CString::from_raw(result.id));
			}
			if !result.title.is_null() {
				drop(CString::from_raw(result.title));
			}
			if !result.subtitle.is_null() {
				drop(CString::from_raw(result.subtitle));
			}
			if !result.icon.is_null() {
				drop(CString::from_raw(result.icon));
			}
			if !result.url.is_null() {
				drop(CString::from_raw(result.url));
			}
		}
		drop(Vec::from_raw_parts(results, count, count));
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_manager_add_json(handle: *mut ActionManagerHandle, json: *const c_char) -> bool {
	if handle.is_null() || json.is_null() {
		return false;
	}

	let action: Action = match sonic_rs::from_str(cstr!(json)) {
		Ok(a) => a,
		Err(_) => return false,
	};

	unsafe { (*handle).manager.add(action).is_ok() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_manager_add_quick_link(
	handle: *mut ActionManagerHandle,
	id: *const c_char,
	name: *const c_char,
	keyword: *const c_char,
	url: *const c_char,
	icon: *const c_char,
) -> bool {
	if handle.is_null() || id.is_null() || name.is_null() || keyword.is_null() || url.is_null() {
		return false;
	}

	let action = Action::quick_link(cstr!(id), cstr!(name), cstr!(keyword), cstr!(url), cstr!(icon));

	unsafe { (*handle).manager.add(action).is_ok() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_manager_add_pattern(
	handle: *mut ActionManagerHandle,
	id: *const c_char,
	name: *const c_char,
	pattern: *const c_char,
	url: *const c_char,
	icon: *const c_char,
) -> bool {
	if handle.is_null() || id.is_null() || name.is_null() || pattern.is_null() || url.is_null() {
		return false;
	}

	let action = Action::pattern(
		cstr!(id),
		cstr!(name),
		cstr!(pattern),
		PatternActionType::OpenUrl(cstr!(url).to_string()),
		cstr!(icon),
	);

	unsafe { (*handle).manager.add(action).is_ok() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_manager_update_json(handle: *mut ActionManagerHandle, json: *const c_char) -> bool {
	if handle.is_null() || json.is_null() {
		return false;
	}

	let action: Action = match sonic_rs::from_str(cstr!(json)) {
		Ok(a) => a,
		Err(_) => return false,
	};

	unsafe { (*handle).manager.update(action).unwrap_or(false) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_manager_remove(handle: *mut ActionManagerHandle, id: *const c_char) -> bool {
	if handle.is_null() || id.is_null() {
		return false;
	}

	unsafe { (*handle).manager.remove(cstr!(id)).unwrap_or(false) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_manager_toggle(handle: *mut ActionManagerHandle, id: *const c_char) -> bool {
	if handle.is_null() || id.is_null() {
		return false;
	}

	unsafe { (*handle).manager.toggle(cstr!(id)).unwrap_or(false) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_manager_get_all_json(handle: *mut ActionManagerHandle) -> *mut c_char {
	if handle.is_null() {
		return ptr::null_mut();
	}

	let actions = unsafe { (*handle).manager.get_all() };
	let json = sonic_rs::to_string(&actions).unwrap_or_default();

	to_cstring_ptr(json)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_manager_import_defaults(handle: *mut ActionManagerHandle) -> bool {
	if handle.is_null() {
		return false;
	}

	unsafe { (*handle).manager.import_defaults().is_ok() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn string_free(s: *mut c_char) {
	if !s.is_null() {
		unsafe { drop(CString::from_raw(s)) };
	}
}
