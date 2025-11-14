use aho_corasick::{AhoCorasick, AhoCorasickBuilder, MatchKind};

pub fn build_automaton_leftmost_longest<P: AsRef<[u8]>>(patterns: &[P]) -> Option<AhoCorasick> {
	if patterns.is_empty() {
		return None;
	}

	AhoCorasickBuilder::new().match_kind(MatchKind::LeftmostLongest).build(patterns).ok()
}
