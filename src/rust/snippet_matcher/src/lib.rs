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
	pub fn new() -> Self { Self { snippets: RwLock::new(Vec::new()), automaton: RwLock::new(None) } }

	pub fn update_snippets(&self, snippets: Vec<Snippet>) {
		let enabled_snippets: Vec<Snippet> = snippets.into_iter().filter(|s| s.enabled).collect();

		let patterns: Vec<&str> = enabled_snippets.iter().map(|s| s.trigger.as_str()).collect();

		let automaton = if !patterns.is_empty() {
			Some(
				AhoCorasickBuilder::new()
					.match_kind(aho_corasick::MatchKind::LeftmostLongest)
					.build(&patterns)
					.expect("Failed to build Aho-Corasick automaton"),
			)
		} else {
			None
		};

		*self.snippets.write() = enabled_snippets;
		*self.automaton.write() = automaton;
	}

	/// Returns (trigger, content, `match_end_position`)
	pub fn find_match(&self, text: &str) -> Option<(String, String, usize)> {
		let automaton_guard = self.automaton.read();
		let automaton = automaton_guard.as_ref()?;

		// Find rightmost match without allocating Vec
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
				id:      "1".to_string(),
				trigger: "\\email".to_string(),
				content: "test@example.com".to_string(),
				enabled: true,
			},
			Snippet {
				id:      "2".to_string(),
				trigger: "\\phone".to_string(),
				content: "123-456-7890".to_string(),
				enabled: true,
			},
		];

		matcher.update_snippets(snippets);

		// Test matching
		let result = matcher.find_match("Please contact me at \\email for");
		assert!(result.is_some());
		let (trigger, content, pos) = result.unwrap();
		assert_eq!(trigger, "\\email");
		assert_eq!(content, "test@example.com");
		assert_eq!(pos, 27); // Position after "\\email"
	}

	#[test]
	fn test_rightmost_match() {
		let matcher = SnippetMatcher::new();

		let snippets = vec![Snippet {
			id:      "1".to_string(),
			trigger: "\\test".to_string(),
			content: "replacement".to_string(),
			enabled: true,
		}];

		matcher.update_snippets(snippets);

		// Should match the rightmost occurrence
		let result = matcher.find_match("\\test some text \\test");
		assert!(result.is_some());
		let (_, _, pos) = result.unwrap();
		assert_eq!(pos, 21); // Position after second "\\test"
	}

	#[test]
	fn test_disabled_snippets() {
		let matcher = SnippetMatcher::new();

		let snippets = vec![
			Snippet { id: "1".to_string(), trigger: "\\enabled".to_string(), content: "yes".to_string(), enabled: true },
			Snippet {
				id:      "2".to_string(),
				trigger: "\\disabled".to_string(),
				content: "no".to_string(),
				enabled: false,
			},
		];

		matcher.update_snippets(snippets);

		assert!(matcher.find_match("\\enabled").is_some());
		assert!(matcher.find_match("\\disabled").is_none());
	}
}
