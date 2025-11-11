pub mod action;
pub mod native_extensions;
pub mod pattern;
pub mod script_filter;

use std::{path::Path, sync::Arc};

use aho_corasick::AhoCorasick;
use parking_lot::RwLock;
use storage_utils::RkyvStorage;

use crate::{action::{Action, ActionKind, ActionResult}, native_extensions::ExtensionRegistry, pattern::{create_result, match_pattern}};

pub struct ActionManager {
	storage:         Arc<RkyvStorage<Action>>,
	actions:         Arc<RwLock<Vec<Action>>>,
	extensions:      Arc<ExtensionRegistry>,
	keyword_matcher: Arc<RwLock<Option<AhoCorasick>>>,
}

impl ActionManager {
	pub fn new(storage_path: impl AsRef<Path>) -> std::io::Result<Self> {
		let storage = Arc::new(RkyvStorage::new(storage_path)?);
		let actions = Arc::new(RwLock::new(storage.get_all()));
		let extensions = Arc::new(ExtensionRegistry::new());
		let keyword_matcher = Arc::new(RwLock::new(None));

		let manager = Self { storage, actions, extensions, keyword_matcher };
		manager.rebuild_keyword_matcher();
		Ok(manager)
	}

	pub fn add(&self, action: Action) -> std::io::Result<()> {
		self.storage.add(action.clone())?;
		self.actions.write().push(action);
		self.rebuild_keyword_matcher();
		Ok(())
	}

	pub fn update(&self, action: Action) -> std::io::Result<bool> {
		let modified = self.storage.update(|actions| {
			if let Some(pos) = actions.iter().position(|a| a.id == action.id) {
				actions[pos] = action.clone();
				true
			} else {
				false
			}
		})?;

		if modified {
			let mut actions = self.actions.write();
			if let Some(pos) = actions.iter().position(|a| a.id == action.id) {
				actions[pos] = action;
			}
			drop(actions);
			self.rebuild_keyword_matcher();
		}

		Ok(modified)
	}

	pub fn remove(&self, id: &str) -> std::io::Result<bool> {
		let modified = self.storage.update(|actions| {
			let before_len = actions.len();
			actions.retain(|a| a.id != id);
			actions.len() != before_len
		})?;

		if modified {
			self.actions.write().retain(|a| a.id != id);
			self.rebuild_keyword_matcher();
		}

		Ok(modified)
	}

	pub fn toggle(&self, id: &str) -> std::io::Result<bool> {
		let modified = self.storage.update(|actions| {
			if let Some(action) = actions.iter_mut().find(|a| a.id == id) {
				action.enabled = !action.enabled;
				true
			} else {
				false
			}
		})?;

		if modified && let Some(action) = self.actions.write().iter_mut().find(|a| a.id == id) {
			action.enabled = !action.enabled;
		}

		self.rebuild_keyword_matcher();
		Ok(modified)
	}

	pub fn get_all(&self) -> Vec<Action> { self.actions.read().clone() }

	pub fn get_by_type(&self, filter: impl Fn(&ActionKind) -> bool) -> Vec<Action> {
		self.actions.read().iter().filter(|a| filter(&a.kind)).cloned().collect()
	}

	pub fn search(&self, query: &str) -> Vec<ActionResult> {
		let actions = self.actions.read();
		let mut results = Vec::new();

		for action in actions.iter().filter(|a| a.enabled) {
			match &action.kind {
				ActionKind::QuickLink { keyword, url } => {
					if let Some(search_query) = self.match_quick_link(query, keyword) {
						let expanded_url = url.replace("{query}", &urlencoding::encode(search_query));
						results.push(ActionResult::new(
							format!("{}:{}", action.id, search_query),
							format!("{}: {}", action.name, search_query),
							expanded_url.clone(),
							&action.icon,
							100.0,
							crate::action::ResultAction::OpenUrl(expanded_url),
						));
					}
				}

				ActionKind::Pattern { pattern, action: action_type } => {
					if let Some(captures) = match_pattern(pattern, query) {
						let result = create_result(&action.id, &action.name, pattern, action_type, &captures, &action.icon);
						results.push(result);
					}
				}

				ActionKind::ScriptFilter { keyword, script_path, extension_dir } => {
					if let Some(search_query) = self.match_quick_link(query, keyword) {
						println!("[ActionManager] Executing script filter '{}' with query: '{}'", action.name, search_query);
						match script_filter::execute_script_filter(script_path, extension_dir, search_query, &action.id) {
							Ok(script_results) => {
								println!("[ActionManager] Script filter returned {} results", script_results.len());
								results.extend(script_results);
							}
							Err(e) => {
								println!("[ActionManager] Script filter execution failed: {}", e);
								results.push(ActionResult::new(
									format!("{}:error", action.id),
									"Script Error",
									format!("Failed to execute: {}", e),
									"exclamationmark.triangle",
									0.0,
									crate::action::ResultAction::CopyText(e),
								));
							}
						}
					}
				}

				ActionKind::NativeExtension { keyword, extension_id } => {
					if let Some(search_query) = self.match_quick_link(query, keyword) {
						let extension_results = self.extensions.search(extension_id, search_query);
						results.extend(extension_results);
					}
				}
			}
		}

		results
	}

	fn match_quick_link<'a>(&self, query: &'a str, keyword: &str) -> Option<&'a str> {
		let trimmed = query.trim();

		if let Some(after_keyword) = trimmed.strip_prefix(keyword)
			&& (after_keyword.is_empty() || after_keyword.starts_with(' ') || after_keyword.starts_with('\t'))
		{
			return Some(after_keyword.trim());
		}

		None
	}

	pub fn import_defaults(&self) -> std::io::Result<()> {
		let defaults = vec![
			Action::quick_link("google", "Google", "g", "https://www.google.com/search?q={query}", "web:google"),
			Action::quick_link("duckduckgo", "DuckDuckGo", "ddg", "https://duckduckgo.com/?q={query}", "web:duckduckgo"),
			Action::quick_link("github", "GitHub", "gh", "https://github.com/search?q={query}", "web:github"),
			Action::quick_link(
				"stackoverflow",
				"Stack Overflow",
				"so",
				"https://stackoverflow.com/search?q={query}",
				"web:stackoverflow",
			),
			Action::quick_link(
				"wikipedia",
				"Wikipedia",
				"wiki",
				"https://en.wikipedia.org/wiki/Special:Search?search={query}",
				"web:wikipedia",
			),
			Action::quick_link(
				"youtube",
				"YouTube",
				"yt",
				"https://www.youtube.com/results?search_query={query}",
				"web:youtube",
			),
		];

		for action in defaults {
			if !self.actions.read().iter().any(|a| a.id == action.id) {
				self.add(action)?;
			}
		}

		Ok(())
	}

	pub fn storage_path(&self) -> &Path { self.storage.path() }

	fn rebuild_keyword_matcher(&self) {
		let actions = self.actions.read();
		let mut keywords = Vec::new();

		for action in actions.iter().filter(|a| a.enabled) {
			let keyword = match &action.kind {
				ActionKind::QuickLink { keyword, .. }
				| ActionKind::ScriptFilter { keyword, .. }
				| ActionKind::NativeExtension { keyword, .. } => keyword.as_str(),
				ActionKind::Pattern { .. } => continue,
			};
			keywords.push(keyword);
		}

		if keywords.is_empty() {
			*self.keyword_matcher.write() = None;
			return;
		}

		match AhoCorasick::new(&keywords) {
			Ok(ac) => {
				*self.keyword_matcher.write() = Some(ac);
			}
			Err(e) => {
				eprintln!("[ActionManager] Failed to build keyword matcher: {}", e);
				*self.keyword_matcher.write() = None;
			}
		}
	}
}

#[cfg(test)]
mod tests {
	use tempfile::NamedTempFile;

	use super::*;

	#[test]
	fn test_quick_link() {
		let temp = NamedTempFile::new().unwrap();
		let manager = ActionManager::new(temp.path()).unwrap();

		let action = Action::quick_link("gh", "GitHub", "gh", "https://github.com/search?q={query}", "magnifyingglass");

		manager.add(action).unwrap();

		let results = manager.search("gh rust");
		assert_eq!(results.len(), 1);
		assert!(results[0].title.contains("rust"));

		match &results[0].action {
			crate::action::ResultAction::OpenUrl(url) => {
				assert!(url.contains("github.com/search?q=rust"));
			}
			_ => panic!("Expected OpenUrl action"),
		}
	}

	#[test]
	fn test_pattern_action() {
		let temp = NamedTempFile::new().unwrap();
		let manager = ActionManager::new(temp.path()).unwrap();

		let action = Action::pattern(
			"gh-repo",
			"GitHub Repo",
			"gh {owner}/{repo}",
			crate::action::PatternActionType::OpenUrl("https://github.com/{owner}/{repo}".to_string()),
			"chevron.left.forwardslash.chevron.right",
		);

		manager.add(action).unwrap();

		let results = manager.search("gh rust-lang/rust");
		assert_eq!(results.len(), 1);

		match &results[0].action {
			crate::action::ResultAction::OpenUrl(url) => {
				assert_eq!(url, "https://github.com/rust-lang/rust");
			}
			_ => panic!("Expected OpenUrl action"),
		}
	}

	#[test]
	fn test_toggle_action() {
		let temp = NamedTempFile::new().unwrap();
		let manager = ActionManager::new(temp.path()).unwrap();

		let action = Action::quick_link("test", "Test", "t", "https://example.com", "sparkles");
		manager.add(action).unwrap();

		assert_eq!(manager.search("t hello").len(), 1);

		manager.toggle("test").unwrap();

		assert_eq!(manager.search("t hello").len(), 0);
	}
}
