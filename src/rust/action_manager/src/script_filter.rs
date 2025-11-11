use std::{io::Read, path::{Path, PathBuf}, process::{Command, Stdio}, time::{Duration, Instant}};

use lru::LruCache;
use parking_lot::RwLock;
use rustc_hash::FxHasher;
use serde::{Deserialize, Serialize};
use sonic_rs::{JsonContainerTrait, JsonValueTrait};
use wait_timeout::ChildExt;

use crate::action::{ActionResult, ResultAction};

type CacheKey = u64;

struct CacheEntry {
	results:   Vec<ActionResult>,
	timestamp: Instant,
}

static SCRIPT_CACHE: RwLock<Option<LruCache<CacheKey, CacheEntry>>> = RwLock::new(None);

const SCRIPT_TIMEOUT_MS: u64 = 2000;
const CACHE_TTL_MS: u64 = 2000;
const CACHE_SIZE: usize = 100;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScriptOutput {
	pub items:     Vec<ScriptItem>,
	#[serde(skip_serializing_if = "Option::is_none")]
	pub variables: Option<sonic_rs::Value>,
	#[serde(skip_serializing_if = "Option::is_none")]
	pub rerun:     Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScriptItem {
	pub title:        String,
	#[serde(skip_serializing_if = "Option::is_none")]
	pub subtitle:     Option<String>,
	#[serde(skip_serializing_if = "Option::is_none")]
	pub arg:          Option<String>,
	#[serde(skip_serializing_if = "Option::is_none")]
	pub icon:         Option<ScriptIcon>,
	#[serde(default = "default_true")]
	pub valid:        bool,
	#[serde(skip_serializing_if = "Option::is_none")]
	pub autocomplete: Option<String>,
	#[serde(skip_serializing_if = "Option::is_none")]
	pub quicklook:    Option<String>,
	#[serde(skip_serializing_if = "Option::is_none")]
	pub uid:          Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScriptIcon {
	pub path:   String,
	#[serde(skip_serializing_if = "Option::is_none")]
	pub r#type: Option<String>,
}

fn default_true() -> bool { true }

fn init_cache() {
	let mut cache = SCRIPT_CACHE.write();
	if cache.is_none() {
		*cache = Some(LruCache::new(std::num::NonZeroUsize::new(CACHE_SIZE).unwrap()));
	}
}

fn cache_key(script_path: &str, query: &str) -> CacheKey {
	use std::hash::{Hash, Hasher};
	let mut hasher = FxHasher::default();
	script_path.hash(&mut hasher);
	query.hash(&mut hasher);
	hasher.finish()
}

fn check_cache(key: CacheKey) -> Option<Vec<ActionResult>> {
	init_cache();
	let mut cache = SCRIPT_CACHE.write();

	if let Some(ref mut lru) = *cache
		&& let Some(entry) = lru.get(&key)
		&& entry.timestamp.elapsed() < Duration::from_millis(CACHE_TTL_MS)
	{
		return Some(entry.results.clone());
	}
	None
}

fn store_cache(key: CacheKey, results: Vec<ActionResult>) {
	init_cache();
	let mut cache = SCRIPT_CACHE.write();

	if let Some(ref mut lru) = *cache {
		lru.put(key, CacheEntry { results, timestamp: Instant::now() });
	}
}

pub fn execute_script_filter(
	script_path: &str,
	extension_dir: &str,
	query: &str,
	action_id: &str,
) -> Result<Vec<ActionResult>, String> {
	let key = cache_key(script_path, query);
	if let Some(cached) = check_cache(key) {
		return Ok(cached);
	}

	let script_path = if Path::new(script_path).is_absolute() {
		PathBuf::from(script_path)
	} else {
		Path::new(extension_dir).join(script_path)
	};

	if !script_path.exists() {
		return Err(format!("Script not found: {}", script_path.display()));
	}

	let manifest_path = Path::new(extension_dir).join("manifest.json");
	let env_vars: Vec<(String, String)> = if manifest_path.exists() {
		if let Ok(content) = std::fs::read(&manifest_path) {
			if let Ok(manifest) = sonic_rs::from_slice::<sonic_rs::Value>(&content) {
				if let Some(env) = manifest.get("env").and_then(|e| e.as_object()) {
					env.iter().filter_map(|(k, v)| v.as_str().map(|s| (k.to_string(), s.to_string()))).collect()
				} else {
					Vec::new()
				}
			} else {
				Vec::new()
			}
		} else {
			Vec::new()
		}
	} else {
		Vec::new()
	};

	let mut command = Command::new(&script_path);
	command.arg(query).current_dir(extension_dir).stdout(Stdio::piped()).stderr(Stdio::piped());

	for (key, value) in env_vars {
		command.env(key, value);
	}

	let mut child = command.spawn().map_err(|e| format!("Failed to execute script: {}", e))?;

	let timeout = Duration::from_millis(SCRIPT_TIMEOUT_MS);

	let status = match child.wait_timeout(timeout).map_err(|e| format!("Failed to wait for script: {}", e))? {
		Some(status) => status,
		None => {
			let _ = child.kill();
			let _ = child.wait();
			return Err(format!("Script timed out after {}ms", SCRIPT_TIMEOUT_MS));
		}
	};

	let mut stdout = Vec::new();
	let mut stderr = Vec::new();

	if let Some(ref mut out) = child.stdout {
		let _ = out.read_to_end(&mut stdout);
	}
	if let Some(ref mut err) = child.stderr {
		let _ = err.read_to_end(&mut stderr);
	}

	let output = std::process::Output { status, stdout, stderr };

	if !output.status.success() {
		let stderr = String::from_utf8_lossy(&output.stderr);
		return Err(format!("Script failed: {}", stderr));
	}

	let script_output: ScriptOutput = sonic_rs::from_slice(&output.stdout)
		.map_err(|e| format!("Failed to parse JSON: {}. Output: {}", e, String::from_utf8_lossy(&output.stdout)))?;

	let results: Vec<ActionResult> = script_output
		.items
		.into_iter()
		.enumerate()
		.filter(|(_, item)| item.valid)
		.map(|(i, item)| {
			let action = if let Some(arg) = &item.arg {
				if arg.starts_with("http://") || arg.starts_with("https://") || arg.contains("://") {
					ResultAction::OpenUrl(arg.clone())
				} else if arg.starts_with("cmd:") {
					let cmd_str = arg.strip_prefix("cmd:").unwrap_or(arg);
					ResultAction::RunCommand { cmd: "/bin/sh".to_string(), args: vec!["-c".to_string(), cmd_str.to_string()] }
				} else if arg.starts_with('/') || arg.starts_with("~/") {
					ResultAction::OpenUrl(format!("file://{}", arg))
				} else {
					ResultAction::OpenUrl(arg.clone())
				}
			} else {
				ResultAction::CopyText(item.title.clone())
			};

			let (icon, icon_path) = if let Some(icon_obj) = &item.icon {
				let resolved_path = if Path::new(&icon_obj.path).is_absolute() {
					icon_obj.path.clone()
				} else {
					Path::new(extension_dir).join(&icon_obj.path).to_string_lossy().to_string()
				};

				if Path::new(&resolved_path).exists() {
					("doc.text".to_string(), Some(resolved_path))
				} else {
					("doc.text".to_string(), None)
				}
			} else {
				("doc.text".to_string(), None)
			};

			let mut result = ActionResult::new(
				item.uid.unwrap_or_else(|| format!("{}-{}", action_id, i)),
				item.title,
				item.subtitle.unwrap_or_default(),
				icon,
				200.0,
				action,
			);

			if let Some(path) = icon_path {
				result = result.with_icon_path(path);
			}

			if let Some(quicklook) = item.quicklook {
				result = result.with_quicklook(quicklook);
			}

			result
		})
		.collect();

	store_cache(key, results.clone());

	Ok(results)
}
