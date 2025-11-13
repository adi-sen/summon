use aho_corasick::{AhoCorasick, AhoCorasickBuilder};
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Snippet {
	pub id:      String,
	pub trigger: String,
	pub content: String,
	pub enabled: bool,
}

pub struct SnippetMatcher {
	snippets:  RwLock<Vec<Snippet>>,
	automaton: RwLock<Option<AhoCorasick>>,
}

impl SnippetMatcher {
	#[must_use]
	pub fn new() -> Self { Self { snippets: RwLock::new(Vec::new()), automaton: RwLock::new(None) } }

	/// # Panics
	/// Panics if pattern building fails (should not happen with valid inputs)
	pub fn update_snippets(&self, snippets: Vec<Snippet>) {
		let enabled_snippets: Vec<Snippet> = snippets.into_iter().filter(|s| s.enabled).collect();

		let patterns: Vec<&str> = enabled_snippets.iter().map(|s| s.trigger.as_str()).collect();

		let automaton = if patterns.is_empty() {
			None
		} else {
			Some(
				AhoCorasickBuilder::new()
					.match_kind(aho_corasick::MatchKind::LeftmostLongest)
					.build(&patterns)
					.expect("Failed to build Aho-Corasick automaton"),
			)
		};

		*self.snippets.write() = enabled_snippets;
		*self.automaton.write() = automaton;
	}

	pub fn find_match(&self, text: &str) -> Option<(String, String, usize)> {
		let automaton_guard = self.automaton.read();
		let automaton = automaton_guard.as_ref()?;

		let last_match = automaton.find_iter(text).last()?;
		let pattern_idx = last_match.pattern().as_usize();

		let snippets = self.snippets.read();
		let snippet = snippets.get(pattern_idx)?;

		Some((snippet.trigger.clone(), snippet.content.clone(), last_match.end()))
	}

	pub fn stats(&self) -> (usize, usize) {
		let snippets = self.snippets.read();
		let total = snippets.len();
		let enabled = snippets.iter().filter(|s| s.enabled).count();
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
			Snippet {
				id:      "1".to_owned(),
				trigger: "\\email".to_owned(),
				content: "test@example.com".to_owned(),
				enabled: true,
			},
			Snippet {
				id:      "2".to_owned(),
				trigger: "\\phone".to_owned(),
				content: "123-456-7890".to_owned(),
				enabled: true,
			},
		];

		matcher.update_snippets(snippets);

		let result = matcher.find_match("Please contact me at \\email for");
		assert!(result.is_some());
		let (trigger, content, _pos) = result.unwrap();
		assert_eq!(trigger, "\\email");
		assert_eq!(content, "test@example.com");
	}

	#[test]
	fn test_rightmost_match() {
		let matcher = SnippetMatcher::new();

		let snippets = vec![Snippet {
			id:      "1".to_owned(),
			trigger: "\\test".to_owned(),
			content: "replacement".to_owned(),
			enabled: true,
		}];

		matcher.update_snippets(snippets);

		let result = matcher.find_match("\\test some text \\test");
		assert!(result.is_some());
		let (_, _, _pos) = result.unwrap();
	}

	#[test]
	fn test_disabled_snippets() {
		let matcher = SnippetMatcher::new();

		let snippets = vec![
			Snippet { id: "1".to_owned(), trigger: "\\enabled".to_owned(), content: "yes".to_owned(), enabled: true },
			Snippet { id: "2".to_owned(), trigger: "\\disabled".to_owned(), content: "no".to_owned(), enabled: false },
		];

		matcher.update_snippets(snippets);

		assert!(matcher.find_match("\\enabled").is_some());
		assert!(matcher.find_match("\\disabled").is_none());
	}
}
