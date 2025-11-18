use std::sync::Arc;

use aho_corasick::AhoCorasick;
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug)]
pub struct Snippet {
	pub id:      String,
	pub trigger: Arc<str>,
	pub content: Arc<str>,
	pub enabled: bool,
}

#[derive(Deserialize, Serialize)]
struct SnippetDTO {
	id:      String,
	trigger: String,
	content: String,
	enabled: bool,
}

impl From<SnippetDTO> for Snippet {
	fn from(dto: SnippetDTO) -> Self {
		Self { id: dto.id, trigger: dto.trigger.into(), content: dto.content.into(), enabled: dto.enabled }
	}
}

pub struct SnippetMatcher {
	snippets:  RwLock<Vec<Snippet>>,
	automaton: RwLock<Option<AhoCorasick>>,
}

impl SnippetMatcher {
	#[must_use]
	#[allow(clippy::missing_const_for_fn)]
	pub fn new() -> Self { Self { snippets: RwLock::new(Vec::new()), automaton: RwLock::new(None) } }

	pub fn update_snippets(&self, snippets: Vec<Snippet>) {
		let enabled_snippets: Vec<Snippet> = snippets.into_iter().filter(|s| s.enabled).collect();

		let patterns: Vec<&str> = enabled_snippets.iter().map(|s| &*s.trigger).collect();
		let automaton = shared_utils::build_automaton_leftmost_longest(&patterns);

		*self.snippets.write() = enabled_snippets;
		*self.automaton.write() = automaton;
	}

	#[allow(clippy::significant_drop_tightening)]
	pub fn find_match(&self, text: &str) -> Option<(Arc<str>, Arc<str>, usize)> {
		let automaton_guard = self.automaton.read();
		let automaton = automaton_guard.as_ref()?;
		let last_match = automaton.find_iter(text).last()?;
		let pattern_idx = last_match.pattern().as_usize();
		let match_end = last_match.end();
		drop(automaton_guard);

		let snippets = self.snippets.read();
		let snippet = snippets.get(pattern_idx)?;
		let result = (Arc::clone(&snippet.trigger), Arc::clone(&snippet.content), match_end);
		drop(snippets);

		Some(result)
	}

	pub fn stats(&self) -> (usize, usize) {
		let snippets = self.snippets.read();
		let total = snippets.len();
		let enabled = snippets.iter().filter(|s| s.enabled).count();
		drop(snippets);
		(total, enabled)
	}
}

impl Default for SnippetMatcher {
	fn default() -> Self { Self::new() }
}

#[cfg(test)]
mod tests {
	use super::*;

	#[test]
	fn test_basic_matching() {
		let matcher = SnippetMatcher::new();

		let snippets = vec![
			Snippet { id: "1".to_owned(), trigger: "\\email".into(), content: "test@example.com".into(), enabled: true },
			Snippet { id: "2".to_owned(), trigger: "\\phone".into(), content: "123-456-7890".into(), enabled: true },
		];

		matcher.update_snippets(snippets);

		let result = matcher.find_match("Please contact me at \\email for");
		assert!(result.is_some());
		let (trigger, content, _pos) = result.unwrap();
		assert_eq!(&*trigger, "\\email");
		assert_eq!(&*content, "test@example.com");
	}

	#[test]
	fn test_rightmost_match() {
		let matcher = SnippetMatcher::new();

		let snippets =
			vec![Snippet { id: "1".to_owned(), trigger: "\\test".into(), content: "replacement".into(), enabled: true }];

		matcher.update_snippets(snippets);

		let result = matcher.find_match("\\test some text \\test");
		assert!(result.is_some());
		let (_, _, _pos) = result.unwrap();
	}

	#[test]
	fn test_disabled_snippets() {
		let matcher = SnippetMatcher::new();

		let snippets = vec![
			Snippet { id: "1".to_owned(), trigger: "\\enabled".into(), content: "yes".into(), enabled: true },
			Snippet { id: "2".to_owned(), trigger: "\\disabled".into(), content: "no".into(), enabled: false },
		];

		matcher.update_snippets(snippets);

		assert!(matcher.find_match("\\enabled").is_some());
		assert!(matcher.find_match("\\disabled").is_none());
	}
}
