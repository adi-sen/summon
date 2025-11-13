use std::cell::RefCell;

use nucleo_matcher::{Config, Matcher, pattern::{CaseMatching, Normalization, Pattern}};

pub struct FuzzyMatcher {
	matcher: RefCell<Matcher>,
}

impl FuzzyMatcher {
	#[inline]
	#[must_use]
	pub fn new() -> Self { Self { matcher: RefCell::new(Matcher::new(Config::DEFAULT)) } }

	#[inline]
	pub fn match_with_indices(&self, candidate: &str, query: &str) -> Option<(i64, Vec<usize>)> {
		let pattern = Pattern::parse(query, CaseMatching::Smart, Normalization::Smart);
		let haystack = nucleo_matcher::Utf32String::from(candidate);
		let mut indices = Vec::new();

		let score = pattern.indices(haystack.slice(..), &mut self.matcher.borrow_mut(), &mut indices)?;

		let bonus_score = Self::calculate_bonus(candidate, query, i64::from(score), &indices);

		Some((bonus_score, indices.iter().map(|&i| i as usize).collect()))
	}

	#[inline]
	#[allow(clippy::cast_possible_wrap)]
	fn calculate_bonus(candidate: &str, query: &str, base_score: i64, indices: &[u32]) -> i64 {
		let mut bonus = 0i64;

		if candidate.eq_ignore_ascii_case(query) {
			bonus += 10000;
		}

		if candidate.to_lowercase().starts_with(&query.to_lowercase()) {
			bonus += 5000;
		}

		if let Some(&first_idx) = indices.first()
			&& first_idx == 0
		{
			bonus += 2000;
		}

		let mut consecutive = 0;
		for window in indices.windows(2) {
			if window[1] == window[0] + 1 {
				consecutive += 1;
			}
		}
		bonus += consecutive * 100;

		let length_penalty = (candidate.len() as i64).saturating_sub(query.len() as i64) * 10;

		base_score + bonus - length_penalty
	}

	#[inline]
	pub fn fuzzy_match(&self, candidate: &str, query: &str) -> Option<i64> {
		self.match_with_indices(candidate, query).map(|(score, _)| score)
	}

	#[inline]
	pub fn match_indices(&self, candidate: &str, query: &str) -> Option<Vec<usize>> {
		self.match_with_indices(candidate, query).map(|(_, indices)| indices)
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
