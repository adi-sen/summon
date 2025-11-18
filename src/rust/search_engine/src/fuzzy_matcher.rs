use nucleo_matcher::{Config, Matcher, Utf32String, pattern::{CaseMatching, Normalization, Pattern}};
use parking_lot::Mutex;
use smallvec::SmallVec;

pub use nucleo_matcher::pattern::Pattern as FuzzyPattern;

pub struct FuzzyMatcher {
	matcher:     Mutex<Matcher>,
	indices_buf: Mutex<Vec<u32>>,
}

impl FuzzyMatcher {
	#[inline]
	#[must_use]
	pub fn new() -> Self {
		Self { matcher: Mutex::new(Matcher::new(Config::DEFAULT)), indices_buf: Mutex::new(Vec::with_capacity(64)) }
	}

	#[inline]
	#[must_use]
	pub fn parse_pattern(query: &str) -> Pattern { Pattern::parse(query, CaseMatching::Smart, Normalization::Smart) }

	#[inline]
	pub fn match_with_indices(&self, candidate: &str, query: &str) -> Option<(i64, SmallVec<[usize; 8]>)> {
		let pattern = Self::parse_pattern(query);
		self.match_with_pattern(&pattern, candidate, query)
	}

	#[inline]
	pub fn match_with_pattern(
		&self,
		pattern: &Pattern,
		candidate: &str,
		query: &str,
	) -> Option<(i64, SmallVec<[usize; 8]>)> {
		let haystack = Utf32String::from(candidate);
		let mut indices_buf = self.indices_buf.lock();
		indices_buf.clear();

		let score = pattern.indices(haystack.slice(..), &mut self.matcher.lock(), &mut indices_buf)?;

		let bonus_score = Self::calculate_bonus(candidate, query, i64::from(score), &indices_buf);

		Some((bonus_score, indices_buf.iter().map(|&i| i as usize).collect()))
	}

	#[inline]
	#[allow(clippy::cast_possible_wrap)]
	fn calculate_bonus(candidate: &str, query: &str, base_score: i64, indices: &[u32]) -> i64 {
		let mut bonus = 0i64;

		if candidate.eq_ignore_ascii_case(query) {
			bonus += 10000;
		}

		// Use byte-level ASCII case-insensitive prefix check to avoid allocations
		if candidate.len() >= query.len()
			&& candidate.as_bytes()[..query.len()].iter().zip(query.as_bytes()).all(|(a, b)| a.eq_ignore_ascii_case(b))
		{
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
	pub fn match_indices(&self, candidate: &str, query: &str) -> Option<SmallVec<[usize; 8]>> {
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
		let score1 = matcher.fuzzy_match("Safari", "safari");
		let score2 = matcher.fuzzy_match("Safari", "saf");
		let score3 = matcher.fuzzy_match("Visual Studio Code", "code");
		assert!(score1.is_some());
		assert!(score2.is_some());
		assert!(score3.is_some());
	}
}
