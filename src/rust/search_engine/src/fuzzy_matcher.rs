use std::cell::RefCell;

use nucleo_matcher::{Config, Matcher, pattern::{CaseMatching, Normalization, Pattern}};

pub struct FuzzyMatcher {
	matcher: RefCell<Matcher>,
}

impl FuzzyMatcher {
	#[inline]
	pub fn new() -> Self { Self { matcher: RefCell::new(Matcher::new(Config::DEFAULT)) } }

	#[inline]
	pub fn fuzzy_match(&self, candidate: &str, query: &str) -> Option<i64> {
		let pattern = Pattern::parse(query, CaseMatching::Smart, Normalization::Smart);
		let haystack = nucleo_matcher::Utf32String::from(candidate);

		pattern.score(haystack.slice(..), &mut self.matcher.borrow_mut()).map(|score| score as i64)
	}

	#[inline]
	pub fn match_indices(&self, candidate: &str, query: &str) -> Option<Vec<usize>> {
		let pattern = Pattern::parse(query, CaseMatching::Smart, Normalization::Smart);
		let haystack = nucleo_matcher::Utf32String::from(candidate);
		let mut indices = Vec::new();

		pattern
			.indices(haystack.slice(..), &mut self.matcher.borrow_mut(), &mut indices)
			.map(|_| indices.iter().map(|&i| i as usize).collect())
	}
}

impl Default for FuzzyMatcher {
	fn default() -> Self { Self::new() }
}

#[cfg(test)]
mod tests {
	use super::*;

	#[test]
	fn test_exact_match() {
		let matcher = FuzzyMatcher::new();
		let score = matcher.fuzzy_match("Safari", "Safari");
		assert!(score.is_some());
		assert!(score.unwrap() > 0);
	}

	#[test]
	fn test_fuzzy_match() {
		let matcher = FuzzyMatcher::new();

		let score = matcher.fuzzy_match("Visual Studio Code", "vsc");
		assert!(score.is_some());

		let score = matcher.fuzzy_match("Safari", "saf");
		assert!(score.is_some());
	}

	#[test]
	fn test_no_match() {
		let matcher = FuzzyMatcher::new();
		let score = matcher.fuzzy_match("Safari", "xyz");
		assert!(score.is_none());
	}

	#[test]
	fn test_case_insensitive() {
		let matcher = FuzzyMatcher::new();
		// Smart case: lowercase queries are case-insensitive
		let score1 = matcher.fuzzy_match("Safari", "safari");
		let score2 = matcher.fuzzy_match("Safari", "saf");
		let score3 = matcher.fuzzy_match("Visual Studio Code", "code");
		assert!(score1.is_some());
		assert!(score2.is_some());
		assert!(score3.is_some());
	}
}
