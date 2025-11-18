#![allow(clippy::missing_safety_doc, clippy::missing_panics_doc)]
use std::{ffi::{CStr, CString}, ptr, sync::Arc};

use action_manager::{ActionManager, action::{Action, PatternActionType, ResultAction}};
use app_storage::{AppEntry, AppStorage};
use calculator::Calculator;
use clipboard_storage::{ClipboardEntry, ClipboardItemType, ClipboardStorage};
use compact_str::CompactString;
use file_indexer::{FileIndexer, FileIndexerConfig};
use libc::{c_char, size_t};
use parking_lot::Mutex;
use search_engine::{SearchEngine, indexer::{IndexedItem, ItemType}};
use settings_storage::{AppSettings, SettingsStorage};
use snippet_matcher::{Snippet, SnippetMatcher};
use snippet_storage::SnippetStorage;
use sonic_rs::{JsonContainerTrait, JsonValueTrait};

#[global_allocator]
static GLOBAL: mimalloc::MiMalloc = mimalloc::MiMalloc;

macro_rules! cstr {
	($ptr:expr) => {{
		#[allow(unused_unsafe)]
		{
			if $ptr.is_null() { "" } else { unsafe { CStr::from_ptr($ptr) }.to_str().unwrap_or("") }
		}
	}};
}

macro_rules! opt_string {
	($ptr:expr) => {{
		#[allow(unused_unsafe)]
		{
			if $ptr.is_null() { None } else { unsafe { CStr::from_ptr($ptr) }.to_str().ok().map(|s| s.to_string()) }
		}
	}};
}

macro_rules! cstr_owned {
	($ptr:expr) => {{ cstr!($ptr).to_string() }};
}

macro_rules! require_handle {
	($handle:expr, $($ptr:expr),+) => {
		if $handle.is_null() $(|| $ptr.is_null())+ {
			return false;
		}
	};
}

macro_rules! require_handle_ptr {
	($handle:expr, $($ptr:expr),+) => {
		if $handle.is_null() $(|| $ptr.is_null())+ {
			return ptr::null_mut();
		}
	};
}

macro_rules! require_handle_ret {
	($ret_val:expr, $handle:expr, $($ptr:expr),+) => {
		if $handle.is_null() $(|| $ptr.is_null())+ {
			return $ret_val;
		}
	};
}

macro_rules! with_handle {
	($handle:expr, $body:expr) => {{
		if $handle.is_null() {
			return false;
		}
		unsafe {
			let handle_ref = &*$handle;
			$body(handle_ref)
		}
	}};
	($handle:expr,ret = $default:expr, $body:expr) => {{
		if $handle.is_null() {
			return $default;
		}
		unsafe {
			let handle_ref = &*$handle;
			$body(handle_ref)
		}
	}};
}

#[inline]
fn to_cstring_ptr(s: impl Into<Vec<u8>>) -> *mut c_char {
	CString::new(s).ok().map_or(ptr::null_mut(), CString::into_raw)
}

#[inline]
fn opt_to_cstring_ptr<T: AsRef<str>>(opt: Option<T>) -> *mut c_char {
	opt.and_then(|s| CString::new(s.as_ref()).ok()).map_or(ptr::null_mut(), CString::into_raw)
}

#[inline]
fn vec_to_c_array<T>(vec: Vec<T>) -> *mut T {
	if vec.is_empty() { ptr::null_mut() } else { Box::into_raw(vec.into_boxed_slice()).cast::<T>() }
}

#[inline]
fn parse_shortcut_json(json_ptr: *const c_char, default_key: &str, default_mods: &[&str]) -> (String, Vec<String>) {
	let shortcut: sonic_rs::Value = if json_ptr.is_null() {
		sonic_rs::json!({"key": default_key, "modifiers": default_mods})
	} else {
		sonic_rs::from_str(cstr!(json_ptr)).unwrap_or(sonic_rs::json!({}))
	};
	let key = shortcut["key"].as_str().unwrap_or(default_key).to_owned();
	let mods: Vec<String> = shortcut["modifiers"]
		.as_array()
		.map(|arr| arr.iter().filter_map(|v| v.as_str().map(std::borrow::ToOwned::to_owned)).collect())
		.unwrap_or_default();
	(key, mods)
}

#[inline]
unsafe fn cstring_array_to_vec(arr: &CStringArray) -> Vec<&'static str> {
	if arr.data.is_null() {
		return vec![];
	}
	unsafe {
		std::slice::from_raw_parts(arr.data, arr.len)
			.iter()
			.filter_map(|&ptr| if ptr.is_null() { None } else { CStr::from_ptr(ptr).to_str().ok() })
			.collect()
	}
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

macro_rules! array_free {
	($fn_name:ident, $type:ty, $($field:ident),+) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(items: *mut $type, count: size_t) {
			if items.is_null() || count == 0 {
				return;
			}
			unsafe {
				for i in 0..count {
					let item = &(*items.add(i));
					$(
						if !item.$field.is_null() {
							drop(CString::from_raw(item.$field));
						}
					)+
				}
				drop(Vec::from_raw_parts(items, count, count));
			}
		}
	};
}

macro_rules! handle_free {
	($fn_name:ident, $handle_type:ty) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(handle: *mut $handle_type) {
			if !handle.is_null() {
				unsafe { drop(Box::from_raw(handle)) };
			}
		}
	};
}

macro_rules! storage_len {
	($fn_name:ident, $handle_type:ty) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(handle: *mut $handle_type) -> size_t {
			with_handle!(handle, ret = 0, |h: &$handle_type| h.inner.len())
		}
	};
}

macro_rules! storage_clear {
	($fn_name:ident, $handle_type:ty) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(handle: *mut $handle_type) -> bool {
			with_handle!(handle, |h: &$handle_type| h.inner.clear().is_ok())
		}
	};
}

macro_rules! settings_json_getter {
	($fn_name:ident, $expr:expr) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(handle: *mut SettingsStorageHandle) -> *mut c_char {
			if handle.is_null() {
				return ptr::null_mut();
			}
			let settings = unsafe { (*handle).inner.get() };
			sonic_rs::to_string(&$expr(&settings)).ok().map(to_cstring_ptr).unwrap_or(ptr::null_mut())
		}
	};
}

macro_rules! void_method {
	($fn_name:ident, $handle_type:ty, $field:ident, $method:ident) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(handle: *mut $handle_type) {
			if !handle.is_null() {
				unsafe { (*handle).$field.$method() };
			}
		}
	};
}

macro_rules! bool_method {
	($fn_name:ident, $handle_type:ty, $field:ident, $method:ident) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(handle: *mut $handle_type) -> bool {
			with_handle!(handle, |h: &$handle_type| h.$field.$method())
		}
	};
}

macro_rules! size_method {
	($fn_name:ident, $handle_type:ty, $field:ident, $method:ident) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(handle: *mut $handle_type) -> size_t {
			with_handle!(handle, ret = 0, |h: &$handle_type| h.$field.$method())
		}
	};
}

macro_rules! struct_free {
	($fn_name:ident, $type:ty, $($field:ident),+) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(ptr: *mut $type) {
			if ptr.is_null() {
				return;
			}
			unsafe {
				let obj = Box::from_raw(ptr);
				$(
					if !obj.$field.is_null() {
						drop(CString::from_raw(obj.$field));
					}
				)+
			}
		}
	};
}

macro_rules! snippet_op {
	($fn_name:ident, $method:ident) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(
			handle: *mut SnippetStorageHandle,
			id: *const c_char,
			trigger: *const c_char,
			content: *const c_char,
			enabled: bool,
			category: *const c_char,
		) -> bool {
			with_handle!(handle, |h: &SnippetStorageHandle| {
				h.inner.$method(snippet_storage::Snippet {
					id: cstr_owned!(id),
					trigger: cstr_owned!(trigger),
					content: cstr_owned!(content),
					enabled,
					category: cstr_owned!(category),
				})
			})
		}
	};
}

macro_rules! storage_method {
	($fn_name:ident, $handle_type:ty, $method:ident, $param_type:ty) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(handle: *mut $handle_type, param: $param_type) -> bool {
			with_handle!(handle, |h: &$handle_type| h.inner.$method(param).is_ok())
		}
	};
}

macro_rules! manager_str_method {
	($fn_name:ident, $method:ident) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(handle: *mut ActionManagerHandle, id: *const c_char) -> bool {
			require_handle!(handle, id);
			unsafe { (*handle).manager.$method(cstr!(id)).unwrap_or(false) }
		}
	};
}

macro_rules! manager_json_method {
	($fn_name:ident, $method:ident, $result:ident) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(handle: *mut ActionManagerHandle, json: *const c_char) -> bool {
			require_handle!(handle, json);
			let action: Action = match sonic_rs::from_str(cstr!(json)) {
				Ok(a) => a,
				Err(_) => return false,
			};
			unsafe { (*handle).manager.$method(action).$result() }
		}
	};
}

macro_rules! new_from_path {
	($fn_name:ident, $handle_type:ident, $inner_type:ty, $field:ident) => {
		#[unsafe(no_mangle)]
		pub unsafe extern "C" fn $fn_name(path: *const c_char) -> *mut $handle_type {
			if path.is_null() {
				return ptr::null_mut();
			}
			match <$inner_type>::new(cstr!(path)) {
				Ok(inner) => Box::into_raw(Box::new($handle_type { $field: inner })),
				Err(_) => ptr::null_mut(),
			}
		}
	};
}

pub struct SearchEngineHandle {
	engine:       Arc<Mutex<SearchEngine>>,
	last_results: parking_lot::Mutex<Option<Vec<search_engine::SearchResult>>>,
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
	Box::into_raw(Box::new(SearchEngineHandle {
		engine:       Arc::new(Mutex::new(SearchEngine::new())),
		last_results: parking_lot::Mutex::new(None),
	}))
}

handle_free!(search_engine_free, SearchEngineHandle);

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_add_item(
	handle: *mut SearchEngineHandle,
	id: *const c_char,
	name: *const c_char,
	path: *const c_char,
	item_type: u8,
) -> bool {
	with_handle!(handle, |h: &SearchEngineHandle| {
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
			metadata: None,
		};
		let engine = h.engine.lock();
		engine.indexer().write().add_item(item);
		engine.clear_cache();
		true
	})
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_search(
	handle: *mut SearchEngineHandle,
	query: *const c_char,
	limit: size_t,
	out_count: *mut size_t,
) -> *mut CSearchResult {
	require_handle_ptr!(handle, query, out_count);

	let results = {
		let engine = unsafe { (*handle).engine.lock() };
		if let Ok(results) = engine.search(cstr!(query), limit) {
			results
		} else {
			unsafe { *out_count = 0 };
			return ptr::null_mut();
		}
	};

	if results.is_empty() {
		unsafe { *out_count = 0 };
		return ptr::null_mut();
	}

	let mut c_results = Vec::with_capacity(results.len());

	for r in &results {
		c_results.push(CSearchResult {
			id:    to_cstring_ptr(r.item.id.as_str()),
			name:  to_cstring_ptr(r.item.name.as_str()),
			path:  opt_to_cstring_ptr(r.item.path.as_ref().map(|p| p.as_str())),
			score: r.score,
		});
	}

	*unsafe { (*handle).last_results.lock() } = Some(results);

	unsafe { *out_count = c_results.len() };
	vec_to_c_array(c_results)
}

array_free!(search_results_free, CSearchResult, id, name, path);

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_stats(
	handle: *mut SearchEngineHandle,
	total: *mut size_t,
	apps: *mut size_t,
	files: *mut size_t,
	snippets: *mut size_t,
) -> bool {
	with_handle!(handle, |h: &SearchEngineHandle| {
		let (total_count, apps_count, files_count, snippets_count) = h.engine.lock().indexer().read().stats();

		if !total.is_null() {
			*total = total_count;
		}
		if !apps.is_null() {
			*apps = apps_count;
		}
		if !files.is_null() {
			*files = files_count;
		}
		if !snippets.is_null() {
			*snippets = snippets_count;
		}
		true
	})
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

	let dirs = unsafe { cstring_array_to_vec(&directories) };
	let excludes = unsafe { cstring_array_to_vec(&exclude_patterns) };

	let engine = unsafe { &(*handle).engine };

	let mut new_apps = Vec::with_capacity(100);
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
					new_apps.push((CompactString::new(full_path), CompactString::new(name)));
				}
			}
		}
	}

	let added_count = new_apps.len();
	if !new_apps.is_empty() {
		let items: Vec<IndexedItem> = new_apps
			.into_iter()
			.map(|(full_path, name)| IndexedItem {
				id: full_path.clone(),
				name,
				item_type: ItemType::Application,
				path: Some(full_path),
				metadata: None,
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
	require_handle_ptr!(handle, out_count);

	let c_apps: Vec<CIndexedApp> = {
		let engine = unsafe { &(*handle).engine };
		let lock = engine.lock();
		let indexer = lock.indexer();
		let reader = indexer.read();
		reader
			.get_items_by_type(search_engine::indexer::ItemType::Application)
			.map(|item| CIndexedApp {
				name: to_cstring_ptr(item.name.as_str()),
				path: to_cstring_ptr(item.path.as_ref().map_or("", compact_str::CompactString::as_str)),
			})
			.collect()
	};

	if c_apps.is_empty() {
		unsafe { *out_count = 0 };
		return ptr::null_mut();
	}

	unsafe { *out_count = c_apps.len() };
	vec_to_c_array(c_apps)
}

array_free!(indexed_apps_free, CIndexedApp, name, path);

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_enable_file_search(
	handle: *mut SearchEngineHandle,
	directories: CStringArray,
	extensions: CStringArray,
) -> bool {
	if handle.is_null() || directories.data.is_null() {
		return false;
	}

	let dirs: Vec<std::path::PathBuf> =
		unsafe { cstring_array_to_vec(&directories).into_iter().map(std::path::PathBuf::from).collect() };

	let exts: Option<Vec<String>> = if extensions.data.is_null() {
		None
	} else {
		Some(unsafe { cstring_array_to_vec(&extensions).into_iter().map(String::from).collect() })
	};

	let engine = unsafe { &(*handle).engine };
	engine.lock().enable_file_search(dirs, exts);
	true
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_disable_file_search(handle: *mut SearchEngineHandle) -> bool {
	with_handle!(handle, |h: &SearchEngineHandle| {
		h.engine.lock().disable_file_search();
		true
	})
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_set_file_indexer(
	search_handle: *mut SearchEngineHandle,
	indexer_handle: *mut FileIndexerHandle,
) -> bool {
	if search_handle.is_null() || indexer_handle.is_null() {
		return false;
	}
	let engine = unsafe { &(*search_handle).engine };
	let indexer = unsafe { &(*indexer_handle).indexer };
	engine.lock().set_file_indexer(Arc::clone(indexer));
	true
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn search_engine_clear_file_indexer(handle: *mut SearchEngineHandle) -> bool {
	with_handle!(handle, |h: &SearchEngineHandle| {
		h.engine.lock().clear_file_indexer();
		true
	})
}

pub struct FileIndexerHandle {
	indexer: Arc<FileIndexer>,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn file_indexer_new(
	storage_path: *const c_char,
	config_json: *const c_char,
) -> *mut FileIndexerHandle {
	if storage_path.is_null() {
		return ptr::null_mut();
	}

	let path = cstr!(storage_path);
	let config = if config_json.is_null() {
		FileIndexerConfig::default()
	} else {
		match sonic_rs::from_str::<FileIndexerConfig>(cstr!(config_json)) {
			Ok(cfg) => cfg,
			Err(_) => return ptr::null_mut(),
		}
	};

	match FileIndexer::new(path, config) {
		Ok(indexer) => Box::into_raw(Box::new(FileIndexerHandle { indexer: Arc::new(indexer) })),
		Err(_) => ptr::null_mut(),
	}
}

handle_free!(file_indexer_free, FileIndexerHandle);

void_method!(file_indexer_start_indexing, FileIndexerHandle, indexer, start_indexing);
void_method!(file_indexer_enable, FileIndexerHandle, indexer, enable);
void_method!(file_indexer_disable, FileIndexerHandle, indexer, disable);
size_method!(file_indexer_file_count, FileIndexerHandle, indexer, file_count);
bool_method!(file_indexer_is_enabled, FileIndexerHandle, indexer, is_enabled);
bool_method!(file_indexer_refresh_if_needed, FileIndexerHandle, indexer, refresh_if_needed);

pub struct CalculatorHandle {
	calc: std::cell::RefCell<Calculator>,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn calculator_new() -> *mut CalculatorHandle {
	Box::into_raw(Box::new(CalculatorHandle { calc: std::cell::RefCell::new(Calculator::new()) }))
}

handle_free!(calculator_free, CalculatorHandle);

#[unsafe(no_mangle)]
pub unsafe extern "C" fn calculator_evaluate(handle: *mut CalculatorHandle, expr: *const c_char) -> *mut c_char {
	if handle.is_null() || expr.is_null() {
		return ptr::null_mut();
	}
	with_handle!(handle, ret = ptr::null_mut(), |h: &CalculatorHandle| {
		match h.calc.borrow_mut().evaluate(cstr!(expr)) {
			Some(result) => to_cstring_ptr(result),
			None => ptr::null_mut(),
		}
	})
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn calculator_get_history_json(handle: *mut CalculatorHandle) -> *mut c_char {
	if handle.is_null() {
		return ptr::null_mut();
	}
	unsafe {
		let history_vec: Vec<_> = (*handle).calc.borrow().get_history().iter().cloned().collect();
		let json_entries: Vec<_> =
			history_vec.iter().map(|e| sonic_rs::json!({"query": e.query, "result": e.result})).collect();
		match sonic_rs::to_string(&json_entries) {
			Ok(json) => to_cstring_ptr(json),
			Err(_) => ptr::null_mut(),
		}
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
	let entry = ClipboardEntry::new_text(cstr_owned!(content), timestamp, size, opt_string!(source_app));
	with_handle!(handle, |h: &ClipboardStorageHandle| {
		h.inner.insert_at_front_async(entry);
		true
	})
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
		cstr_owned!(content),
		timestamp,
		cstr_owned!(image_file_path),
		width,
		height,
		size,
		opt_string!(source_app),
	);
	with_handle!(handle, |h: &ClipboardStorageHandle| {
		h.inner.insert_at_front_async(entry);
		true
	})
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn clipboard_storage_get_entries(
	handle: *mut ClipboardStorageHandle,
	start: size_t,
	count: size_t,
	out_count: *mut size_t,
) -> *mut CClipboardEntry {
	require_handle_ptr!(handle, out_count);

	let entries = unsafe { (*handle).inner.get_range(start, count) };

	if entries.is_empty() {
		unsafe { *out_count = 0 };
		return ptr::null_mut();
	}

	let c_entries: Vec<CClipboardEntry> = entries
		.into_iter()
		.map(|e| {
			let (width, height) = e.image_size.map_or((0.0, 0.0), |s| (s.width, s.height));
			CClipboardEntry {
				content:         to_cstring_ptr(e.content),
				timestamp:       e.timestamp,
				item_type:       e.item_type.as_u8(),
				image_file_path: opt_to_cstring_ptr(e.image_file_path),
				image_width:     width,
				image_height:    height,
				size:            e.size,
				source_app:      opt_to_cstring_ptr(e.source_app),
			}
		})
		.collect();

	unsafe { *out_count = c_entries.len() };
	vec_to_c_array(c_entries)
}

array_free!(clipboard_entries_free, CClipboardEntry, content, image_file_path, source_app);

storage_len!(clipboard_storage_len, ClipboardStorageHandle);
storage_method!(clipboard_storage_trim, ClipboardStorageHandle, trim_to, size_t);
storage_clear!(clipboard_storage_clear, ClipboardStorageHandle);

#[unsafe(no_mangle)]
pub unsafe extern "C" fn clipboard_storage_remove_at(handle: *mut ClipboardStorageHandle, index: size_t) -> bool {
	with_handle!(handle, |h: &ClipboardStorageHandle| {
		h.inner.update_async(|entries| {
			if index < entries.len() {
				entries.remove(index);
				true
			} else {
				false
			}
		})
	})
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn clipboard_storage_find_duplicate_text(
	handle: *mut ClipboardStorageHandle,
	content: *const c_char,
) -> i64 {
	require_handle_ret!(-1, handle, content);
	with_handle!(handle, ret = -1, |h: &ClipboardStorageHandle| {
		match h.inner.find_index(|entry| entry.item_type == ClipboardItemType::Text && entry.content == cstr!(content)) {
			Some(index) => index as i64,
			None => -1,
		}
	})
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

handle_free!(snippet_matcher_free, SnippetMatcherHandle);

#[derive(serde::Deserialize)]
struct SnippetDTO {
	id:      String,
	trigger: String,
	content: String,
	enabled: bool,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_matcher_update(handle: *mut SnippetMatcherHandle, json: *const c_char) -> bool {
	if handle.is_null() || json.is_null() {
		return false;
	}
	with_handle!(handle, |h: &SnippetMatcherHandle| {
		match sonic_rs::from_str::<Vec<SnippetDTO>>(cstr!(json)) {
			Ok(dto_snippets) => {
				let snippets = dto_snippets
					.into_iter()
					.map(|dto| Snippet {
						id:      dto.id,
						trigger: dto.trigger.into(),
						content: dto.content.into(),
						enabled: dto.enabled,
					})
					.collect();
				h.matcher.update_snippets(snippets);
				true
			}
			Err(_) => false,
		}
	})
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_matcher_find(
	handle: *mut SnippetMatcherHandle,
	text: *const c_char,
) -> *mut CSnippetMatch {
	if handle.is_null() || text.is_null() {
		return ptr::null_mut();
	}
	with_handle!(handle, ret = ptr::null_mut(), |h: &SnippetMatcherHandle| {
		match h.matcher.find_match(cstr!(text)) {
			Some((trigger, content, _)) => Box::into_raw(Box::new(CSnippetMatch {
				trigger: to_cstring_ptr(trigger.as_ref()),
				content: to_cstring_ptr(content.as_ref()),
			})),
			None => ptr::null_mut(),
		}
	})
}

struct_free!(snippet_match_free, CSnippetMatch, trigger, content);

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
	with_handle!(handle, |h: &SnippetStorageHandle| {
		h.inner.add(snippet_storage::Snippet {
			id: cstr_owned!(id),
			trigger: cstr_owned!(trigger),
			content: cstr_owned!(content),
			enabled,
			category: cstr_owned!(category),
		});
		true
	})
}

snippet_op!(snippet_storage_update, update);

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_storage_delete(handle: *mut SnippetStorageHandle, id: *const c_char) -> bool {
	if handle.is_null() || id.is_null() {
		return false;
	}
	with_handle!(handle, |h: &SnippetStorageHandle| h.inner.delete(cstr!(id)))
}

#[inline]
fn snippets_to_c(snippets: &[snippet_storage::Snippet]) -> (*mut CSnippet, size_t) {
	if snippets.is_empty() {
		return (ptr::null_mut(), 0);
	}
	let c_snippets: Vec<CSnippet> = snippets
		.iter()
		.map(|s| CSnippet {
			id:       to_cstring_ptr(s.id.as_str()),
			trigger:  to_cstring_ptr(s.trigger.as_str()),
			content:  to_cstring_ptr(s.content.as_str()),
			enabled:  s.enabled,
			category: to_cstring_ptr(s.category.as_str()),
		})
		.collect();
	let count = c_snippets.len();
	(vec_to_c_array(c_snippets), count)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_storage_get_all(
	handle: *mut SnippetStorageHandle,
	out_count: *mut size_t,
) -> *mut CSnippet {
	require_handle_ptr!(handle, out_count);
	let snippets = unsafe { (*handle).inner.get_all() };
	let (ptr, count) = snippets_to_c(&snippets);
	unsafe { *out_count = count };
	ptr
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_storage_get_enabled(
	handle: *mut SnippetStorageHandle,
	out_count: *mut size_t,
) -> *mut CSnippet {
	require_handle_ptr!(handle, out_count);
	let snippets = unsafe { (*handle).inner.get_enabled() };
	let (ptr, count) = snippets_to_c(&snippets);
	unsafe { *out_count = count };
	ptr
}

array_free!(snippets_free, CSnippet, id, trigger, content, category);

storage_len!(snippet_storage_len, SnippetStorageHandle);

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_storage_export_json(handle: *mut SnippetStorageHandle) -> *mut c_char {
	if handle.is_null() {
		return ptr::null_mut();
	}
	unsafe {
		match (*handle).inner.export_to_json() {
			Ok(json) => match CString::new(json) {
				Ok(cstr) => cstr.into_raw(),
				Err(_) => ptr::null_mut(),
			},
			Err(_) => ptr::null_mut(),
		}
	}
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn snippet_storage_import_json(
	handle: *mut SnippetStorageHandle,
	json: *const c_char,
	merge: bool,
) -> i64 {
	if handle.is_null() || json.is_null() {
		return -1;
	}

	let json_str = cstr!(json);
	match unsafe { (*handle).inner.import_from_json(json_str, merge) } {
		Ok(count) => count as i64,
		Err(_) => -1,
	}
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
	let entry = AppEntry::new(cstr_owned!(name), cstr_owned!(path));
	unsafe { (*handle).inner.add(entry).is_ok() }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn app_storage_get_all(handle: *mut AppStorageHandle, out_count: *mut size_t) -> *mut CAppEntry {
	if handle.is_null() || out_count.is_null() {
		return ptr::null_mut();
	}

	let entries = unsafe { (*handle).inner.get_all() };

	if entries.is_empty() {
		unsafe { *out_count = 0 };
		return ptr::null_mut();
	}

	let c_entries: Vec<CAppEntry> = entries
		.iter()
		.map(|e| CAppEntry { name: to_cstring_ptr(e.name.as_str()), path: to_cstring_ptr(e.path.as_str()) })
		.collect();

	unsafe { *out_count = c_entries.len() };
	vec_to_c_array(c_entries)
}

array_free!(app_entries_free, CAppEntry, name, path);

storage_len!(app_storage_len, AppStorageHandle);

storage_clear!(app_storage_clear, AppStorageHandle);

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

	let (launcher_key, launcher_mods) = parse_shortcut_json(launcher_shortcut_json, "space", &["command"]);
	let (clipboard_key, clipboard_mods) = parse_shortcut_json(clipboard_shortcut_json, "v", &["command", "shift"]);

	let settings = AppSettings {
		theme: cstr_owned!(theme),
		custom_font_name: cstr_owned!(custom_font_name),
		font_size: cstr_owned!(font_size),
		max_results,
		max_clipboard_items,
		clipboard_retention_days,
		quick_select_modifier: cstr_owned!(quick_select_modifier),
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

struct_free!(settings_free, CAppSettings, theme, custom_font_name, font_size, quick_select_modifier);

settings_json_getter!(settings_storage_get_search_folders, |s: &AppSettings| s.search_folders.clone());
settings_json_getter!(
	settings_storage_get_launcher_shortcut,
	|s: &AppSettings| sonic_rs::json!({"key": s.launcher_shortcut_key, "modifiers": &s.launcher_shortcut_mods})
);
settings_json_getter!(
	settings_storage_get_clipboard_shortcut,
	|s: &AppSettings| sonic_rs::json!({"key": s.clipboard_shortcut_key, "modifiers": &s.clipboard_shortcut_mods})
);

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

new_from_path!(action_manager_new, ActionManagerHandle, ActionManager, manager);

handle_free!(action_manager_free, ActionManagerHandle);

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
	vec_to_c_array(c_results)
}

array_free!(action_results_free, CActionResult, id, title, subtitle, icon, url);

manager_json_method!(action_manager_add_json, add, is_ok);

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

	let action =
		Action::pattern(cstr!(id), cstr!(name), cstr!(pattern), PatternActionType::OpenUrl(cstr_owned!(url)), cstr!(icon));

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

manager_str_method!(action_manager_remove, remove);
manager_str_method!(action_manager_toggle, toggle);

#[unsafe(no_mangle)]
pub unsafe extern "C" fn action_manager_get_all_json(handle: *mut ActionManagerHandle) -> *mut c_char {
	if handle.is_null() {
		return ptr::null_mut();
	}
	unsafe {
		let actions = (*handle).manager.get_all();
		let json = sonic_rs::to_string(&*actions).unwrap_or_default();
		to_cstring_ptr(json)
	}
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
