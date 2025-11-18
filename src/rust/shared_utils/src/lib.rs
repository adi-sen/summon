use aho_corasick::{AhoCorasick, AhoCorasickBuilder, MatchKind};
use parking_lot::RwLock;

pub fn build_automaton_leftmost_longest<P: AsRef<[u8]>>(patterns: &[P]) -> Option<AhoCorasick> {
	if patterns.is_empty() {
		return None;
	}

	AhoCorasickBuilder::new().match_kind(MatchKind::LeftmostLongest).build(patterns).ok()
}

pub struct KeywordMatcherCache {
	automaton:             RwLock<Option<AhoCorasick>>,
	matcher_needs_rebuild: RwLock<bool>,
}

impl KeywordMatcherCache {
	#[must_use]
	pub fn new() -> Self { Self { automaton: RwLock::new(None), matcher_needs_rebuild: RwLock::new(true) } }

	pub fn invalidate(&self) { *self.matcher_needs_rebuild.write() = true; }

	pub fn rebuild<F, P>(&self, pattern_builder: F)
	where
		F: FnOnce() -> Vec<P>,
		P: AsRef<[u8]>,
	{
		let patterns = pattern_builder();
		let automaton = build_automaton_leftmost_longest(&patterns);
		*self.automaton.write() = automaton;
		*self.matcher_needs_rebuild.write() = false;
	}

	pub fn with_automaton<R>(&self, f: impl FnOnce(&AhoCorasick) -> R) -> Option<R> {
		if *self.matcher_needs_rebuild.read() {
			return None;
		}
		let guard = self.automaton.read();
		guard.as_ref().map(f)
	}

	#[must_use]
	pub fn needs_rebuild(&self) -> bool { *self.matcher_needs_rebuild.read() }
}

impl Default for KeywordMatcherCache {
	fn default() -> Self { Self::new() }
}
