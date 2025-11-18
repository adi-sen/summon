pub mod action;
pub mod pattern;
pub mod script_filter;

use std::path::Path;

use shared_utils::KeywordMatcherCache;
use storage_utils::RkyvStorage;

use crate::{action::{Action, ActionKind, ActionResult}, pattern::{create_result, match_pattern}};

pub struct ActionManager {
	storage:         RkyvStorage<Action>,
	keyword_matcher: KeywordMatcherCache,
}

impl ActionManager {
	pub fn new(storage_path: impl AsRef<Path>) -> std::io::Result<Self> {
		let storage = RkyvStorage::new(storage_path)?;
		let keyword_matcher = KeywordMatcherCache::new();

		let manager = Self { storage, keyword_matcher };
		manager.rebuild_keyword_matcher();
		Ok(manager)
	}

	fn invalidate_matcher_if_modified(&self, modified: bool) {
		if modified {
			self.keyword_matcher.invalidate();
		}
	}

	pub fn add(&self, action: Action) -> std::io::Result<()> {
		self.storage.add(action)?;
		self.invalidate_matcher_if_modified(true);
		Ok(())
	}

	pub fn update(&self, action: Action) -> std::io::Result<bool> {
		let action_id = action.id.clone();
		let modified = self.storage.update(|actions| {
			if let Some(pos) = actions.iter().position(|a| a.id == action_id) {
				actions[pos] = action.clone();
				true
			} else {
				false
			}
		})?;

		self.invalidate_matcher_if_modified(modified);
		Ok(modified)
	}

	pub fn remove(&self, id: &str) -> std::io::Result<bool> {
		let modified = self.storage.update(|actions| {
			let before_len = actions.len();
			actions.retain(|a| a.id != id);
			actions.len() != before_len
		})?;

		self.invalidate_matcher_if_modified(modified);
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

		self.invalidate_matcher_if_modified(modified);
		Ok(modified)
	}

	#[inline]
	#[must_use]
	pub fn get_all(&self) -> std::sync::Arc<Vec<Action>> { self.storage.get_all() }

	#[must_use]
	pub fn get_by_type(&self, filter: impl Fn(&ActionKind) -> bool) -> Vec<Action> {
		self.storage.get_all().iter().filter(|a| filter(&a.kind)).cloned().collect()
	}

	#[must_use]
	pub fn search(&self, query: &str) -> Vec<ActionResult> {
		if self.keyword_matcher.needs_rebuild() {
			self.rebuild_keyword_matcher();
		}

		let actions = self.storage.get_all();
		let mut results = Vec::with_capacity(actions.len().min(10));

		for action in actions.iter().filter(|a| a.enabled) {
			match &action.kind {
				ActionKind::QuickLink { keyword, url } => {
					if let Some(search_query) = Self::match_quick_link(query, keyword.as_str()) {
						let expanded_url = url.replace("{query}", &urlencoding::encode(search_query));
						results.push(ActionResult::new(
							format!("{}:{search_query}", action.id),
							format!("{}: {search_query}", action.name),
							expanded_url.clone(),
							action.icon.as_str(),
							100.0,
							crate::action::ResultAction::OpenUrl(expanded_url),
						));
					}
				}

				ActionKind::Pattern { pattern, action: action_type } => {
					if let Some(captures) = match_pattern(pattern.as_str(), query) {
						let result = create_result(
							action.id.as_str(),
							action.name.as_str(),
							pattern.as_str(),
							action_type,
							&captures,
							action.icon.as_str(),
						);
						results.push(result);
					}
				}

				ActionKind::ScriptFilter { keyword, script_path, extension_dir } => {
					if let Some(search_query) = Self::match_quick_link(query, keyword.as_str()) {
						match script_filter::execute_script_filter(
							script_path.as_str(),
							extension_dir.as_str(),
							search_query,
							action.id.as_str(),
						) {
							Ok(script_results) => {
								results.extend(script_results);
							}
							Err(e) => {
								results.push(ActionResult::new(
									format!("{}:error", action.id),
									"Script Error",
									format!("Failed to execute: {e}"),
									"exclamationmark.triangle",
									0.0,
									crate::action::ResultAction::CopyText(e),
								));
							}
						}
					}
				}
			}
		}

		results
	}

	fn match_quick_link<'a>(query: &'a str, keyword: &str) -> Option<&'a str> {
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
				"youtube",
				"YouTube",
				"yt",
				"https://www.youtube.com/results?search_query={query}",
				"web:youtube",
			),
		];

		let existing_actions = self.storage.get_all();
		for action in defaults {
			if !existing_actions.iter().any(|a| a.id == action.id) {
				self.add(action)?;
			}
		}

		Ok(())
	}

	#[must_use]
	pub fn storage_path(&self) -> &Path { self.storage.path() }

	fn rebuild_keyword_matcher(&self) {
		let actions = self.storage.get_all();
		self.keyword_matcher.rebuild(|| {
			actions
				.iter()
				.filter(|a| a.enabled)
				.filter_map(|a| match &a.kind {
					ActionKind::QuickLink { keyword, .. } | ActionKind::ScriptFilter { keyword, .. } => Some(keyword.as_str()),
					ActionKind::Pattern { .. } => None,
				})
				.collect()
		});
	}
}
