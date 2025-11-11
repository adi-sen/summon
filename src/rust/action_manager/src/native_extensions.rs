use std::{collections::HashMap, path::{Path, PathBuf}, sync::Arc, time::Instant};

use parking_lot::RwLock;

use crate::action::ActionResult;

pub trait NativeExtension: Send + Sync {
	fn id(&self) -> &str;
	fn search(&self, query: &str) -> Vec<ActionResult>;
	fn reload(&mut self);
}

pub struct ExtensionRegistry {
	extensions: HashMap<String, Arc<RwLock<Box<dyn NativeExtension>>>>,
}

impl ExtensionRegistry {
	pub fn new() -> Self {
		let mut registry = Self { extensions: HashMap::new() };
		registry.register(Box::new(ObsidianWorkspaces::new()));
		registry
	}

	pub fn register(&mut self, extension: Box<dyn NativeExtension>) {
		let id = extension.id().to_string();
		self.extensions.insert(id, Arc::new(RwLock::new(extension)));
	}

	pub fn search(&self, extension_id: &str, query: &str) -> Vec<ActionResult> {
		if let Some(ext) = self.extensions.get(extension_id) { ext.read().search(query) } else { vec![] }
	}

	pub fn reload(&self, extension_id: &str) {
		if let Some(ext) = self.extensions.get(extension_id) {
			ext.write().reload();
		}
	}

	pub fn reload_all(&self) {
		for ext in self.extensions.values() {
			ext.write().reload();
		}
	}
}

impl Default for ExtensionRegistry {
	fn default() -> Self { Self::new() }
}

struct ObsidianWorkspaces {
	workspaces:  Vec<Workspace>,
	last_reload: Option<Instant>,
}

#[derive(Debug, Clone)]
struct Workspace {
	name:       String,
	vault_name: String,
	url:        String,
}

impl ObsidianWorkspaces {
	fn new() -> Self {
		let mut ext = Self { workspaces: Vec::new(), last_reload: None };
		ext.reload();
		ext
	}

	fn find_workspace_files() -> Vec<PathBuf> {
		let mut files = Vec::new();
		let home = std::env::var("HOME").unwrap_or_default();
		let search_dirs = vec![
			format!("{}/Documents/Obsidian", home),
			format!("{}/Library/Mobile Documents/iCloud~md~obsidian/Documents", home),
		];

		for dir in search_dirs {
			if let Ok(entries) = std::fs::read_dir(&dir) {
				for entry in entries.flatten() {
					let path = entry.path();
					if path.is_dir() {
						let workspace_file = path.join(".obsidian/workspaces.json");
						if workspace_file.exists() {
							files.push(workspace_file);
						}
					}
				}
			}
		}

		files
	}

	fn parse_workspaces_file(path: &Path) -> Vec<Workspace> {
		let vault_name = path
			.parent()
			.and_then(|p| p.parent())
			.and_then(|p| p.file_name())
			.and_then(|n| n.to_str())
			.unwrap_or("Unknown")
			.to_string();

		let content = match std::fs::read_to_string(path) {
			Ok(c) => c,
			Err(_) => return vec![],
		};

		let json: serde_json::Value = match serde_json::from_str(&content) {
			Ok(j) => j,
			Err(_) => return vec![],
		};

		let mut workspaces = Vec::new();

		if let Some(workspaces_obj) = json.get("workspaces").and_then(|w| w.as_object()) {
			for (name, _) in workspaces_obj {
				let encoded = urlencoding::encode(name);
				let url = format!("obsidian://advanced-uri?vault={}&workspace={}", vault_name, encoded);
				workspaces.push(Workspace { name: name.clone(), vault_name: vault_name.clone(), url });
			}
		}

		workspaces
	}
}

impl NativeExtension for ObsidianWorkspaces {
	fn id(&self) -> &str { "obsidian-workspaces" }

	fn search(&self, query: &str) -> Vec<ActionResult> {
		let query_lower = query.to_lowercase();

		self
			.workspaces
			.iter()
			.filter(|w| query.is_empty() || w.name.to_lowercase().contains(&query_lower))
			.map(|w| {
				ActionResult::new(
					format!("obsidian-{}", w.name),
					w.name.clone(),
					format!("Open in {}", w.vault_name),
					"doc.text".to_string(),
					1.0,
					crate::action::ResultAction::OpenUrl(w.url.clone()),
				)
			})
			.collect()
	}

	fn reload(&mut self) {
		let start = Instant::now();
		self.workspaces.clear();

		for file in Self::find_workspace_files() {
			self.workspaces.extend(Self::parse_workspaces_file(&file));
		}

		self.last_reload = Some(start);
		println!("[ObsidianWorkspaces] Loaded {} workspaces in {:?}", self.workspaces.len(), start.elapsed());
	}
}
