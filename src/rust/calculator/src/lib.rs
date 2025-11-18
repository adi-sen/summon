use std::collections::VecDeque;

use chrono::{DateTime, Datelike, Local, TimeZone, Utc};
use chrono_tz::Tz;
use rustc_hash::FxHashMap;

const MAX_HISTORY: usize = 50;

fn normalize_timezone(tz: &str) -> &str {
	match tz.to_uppercase().as_str() {
		"EST" | "EDT" | "ET" => "America/New_York",
		"CST" | "CDT" | "CT" => "America/Chicago",
		"MST" | "MDT" | "MT" => "America/Denver",
		"PST" | "PDT" | "PT" => "America/Los_Angeles",
		"UTC" | "GMT" => "UTC",
		"JST" => "Asia/Tokyo",
		"KST" => "Asia/Seoul",
		"IST" => "Asia/Kolkata",
		"CET" | "CEST" => "Europe/Paris",
		"BST" => "Europe/London",
		"AEST" | "AEDT" => "Australia/Sydney",
		_ => tz,
	}
}

#[derive(Clone, Debug)]
pub struct CalculationEntry {
	pub query:  String,
	pub result: String,
}

pub struct Calculator {
	exchange_rates: FxHashMap<String, f64>,
	history:        VecDeque<CalculationEntry>,
}

impl Calculator {
	#[must_use]
	pub fn new() -> Self {
		Self {
			exchange_rates: FxHashMap::from_iter([
				("USD".to_owned(), 1.0),
				("EUR".to_owned(), 0.92),
				("GBP".to_owned(), 0.79),
				("JPY".to_owned(), 149.5),
				("CNY".to_owned(), 7.24),
				("AUD".to_owned(), 1.53),
				("CAD".to_owned(), 1.38),
				("CHF".to_owned(), 0.88),
				("INR".to_owned(), 83.2),
				("KRW".to_owned(), 1320.0),
			]),
			history:        VecDeque::with_capacity(MAX_HISTORY),
		}
	}

	#[must_use]
	#[allow(clippy::cast_precision_loss)]
	pub fn eval_math(&self, expr: &str) -> Option<f64> {
		evalexpr::eval(expr).ok().and_then(|v| {
			v.as_float().ok().or_else(|| {
				#[allow(clippy::cast_precision_loss)]
				v.as_int().ok().map(|i| i as f64)
			})
		})
	}

	#[must_use]
	pub fn convert_currency(&self, query: &str) -> Option<(f64, String, String, f64)> {
		let parts: Vec<&str> = query.split_whitespace().collect();

		if parts.len() < 3 {
			return None;
		}

		let amount: f64 = parts.first()?.parse().ok()?;

		let from_currency = parts.get(1)?.to_uppercase();
		let to_currency = if parts.len() == 4 && parts.get(2)?.eq_ignore_ascii_case("to") {
			parts.get(3)?.to_uppercase()
		} else if parts.len() == 3 {
			parts.get(2)?.to_uppercase()
		} else if parts.len() >= 4 && parts.get(2)?.eq_ignore_ascii_case("in") {
			parts.get(3)?.to_uppercase()
		} else {
			return None;
		};

		let from_rate = self.exchange_rates.get(&from_currency)?;
		let to_rate = self.exchange_rates.get(&to_currency)?;

		let usd_amount = amount / from_rate;
		let result = usd_amount * to_rate;

		Some((amount, from_currency, to_currency, result))
	}

	#[must_use]
	pub fn convert_timezone(&self, query: &str) -> Option<(String, String, String, String)> {
		let parts: Vec<&str> = query.split_whitespace().collect();

		if parts.len() < 3 {
			return None;
		}

		if parts.first()?.eq_ignore_ascii_case("now") && parts.get(1)?.eq_ignore_ascii_case("in") && parts.len() >= 3 {
			let target_tz_str = normalize_timezone(parts.get(2)?);
			let target_tz: Tz = target_tz_str.parse().ok()?;

			let now = Utc::now();
			let target_time = now.with_timezone(&target_tz);

			return Some((
				"now".to_owned(),
				"UTC".to_owned(),
				parts.get(2)?.to_uppercase(),
				target_time.format("%I:%M %p").to_string(),
			));
		}

		let time_str = parts.first()?;
		let from_tz_str = parts.get(1)?;
		let to_tz_str = if parts.len() == 4 && parts.get(2)?.eq_ignore_ascii_case("to") {
			parts.get(3)?
		} else if parts.len() == 3 {
			parts.get(2)?
		} else if parts.len() >= 4 && parts.get(2)?.eq_ignore_ascii_case("in") {
			parts.get(3)?
		} else {
			return None;
		};

		let from_tz: Tz = normalize_timezone(from_tz_str).parse().ok()?;
		let to_tz: Tz = normalize_timezone(to_tz_str).parse().ok()?;

		let time = Self::parse_time(time_str, from_tz)?;

		let target_time = time.with_timezone(&to_tz);

		Some((
			(*time_str).to_string(),
			from_tz_str.to_uppercase(),
			to_tz_str.to_uppercase(),
			target_time.format("%I:%M %p").to_string(),
		))
	}

	fn parse_time(time_str: &str, tz: Tz) -> Option<DateTime<Tz>> {
		let today = Local::now().date_naive();

		if let Some((hours, minutes)) = time_str.split_once(':') {
			let h: u32 = hours.parse().ok()?;
			let m: u32 = minutes.parse().ok()?;
			return tz.with_ymd_and_hms(today.year(), today.month(), today.day(), h, m, 0).single();
		}

		let lower = time_str.to_lowercase();
		if let Some(pm_idx) = lower.find("pm") {
			let h: u32 = lower[..pm_idx].parse().ok()?;
			let h = if h == 12 { 12 } else { h + 12 };
			return tz.with_ymd_and_hms(today.year(), today.month(), today.day(), h, 0, 0).single();
		}

		if let Some(am_idx) = lower.find("am") {
			let h: u32 = lower[..am_idx].parse().ok()?;
			let h = if h == 12 { 0 } else { h };
			return tz.with_ymd_and_hms(today.year(), today.month(), today.day(), h, 0, 0).single();
		}

		None
	}

	pub fn evaluate(&mut self, query: &str) -> Option<String> {
		let trimmed = query.trim();

		if trimmed.split_whitespace().count() >= 3 {
			if let Some((_amount, _from, to, result)) = self.convert_currency(trimmed) {
				let result_str = format!("{result:.2} {to}");
				self.add_to_history(trimmed.to_string(), result_str.clone());
				return Some(result_str);
			}

			if let Some((_, _from, to, result)) = self.convert_timezone(trimmed) {
				let result_str = format!("{result} {to}");
				self.add_to_history(trimmed.to_string(), result_str.clone());
				return Some(result_str);
			}
		}

		if let Some(result) = self.eval_math(trimmed) {
			#[allow(clippy::cast_possible_truncation)]
			let result_str = if result.fract() == 0.0 && result.abs() < 1e10 {
				format!("{}", result as i64)
			} else {
				format!("{result:.6}").trim_end_matches('0').trim_end_matches('.').to_string()
			};
			self.add_to_history(trimmed.to_string(), result_str.clone());
			return Some(result_str);
		}

		None
	}

	fn add_to_history(&mut self, query: String, result: String) {
		if self.history.len() >= MAX_HISTORY {
			self.history.pop_front();
		}
		self.history.push_back(CalculationEntry { query, result });
	}

	#[must_use]
	pub const fn get_history(&self) -> &VecDeque<CalculationEntry> { &self.history }

	pub fn clear_history(&mut self) { self.history.clear(); }
}

impl Default for Calculator {
	fn default() -> Self { Self::new() }
}

#[cfg(test)]
mod tests {
	use super::*;

	#[test]
	fn test_math_eval() {
		let calc = Calculator::new();
		assert_eq!(calc.eval_math("2 + 2"), Some(4.0));
		assert_eq!(calc.eval_math("10 * 5"), Some(50.0));
		assert_eq!(calc.eval_math("16 ^ 0.5"), Some(4.0));
	}

	#[test]
	fn test_evaluate() {
		let mut calc = Calculator::new();
		assert_eq!(calc.evaluate("2 + 2"), Some("4".to_owned()));
		assert_eq!(calc.evaluate("16 ^ 0.5"), Some("4".to_owned()));
		assert_eq!(calc.evaluate("100 USD to EUR"), Some("92.00 EUR".to_owned()));
	}

	#[test]
	#[allow(clippy::float_cmp)]
	fn test_currency_conversion() {
		let calc = Calculator::new();
		let result = calc.convert_currency("100 USD to EUR");
		assert!(result.is_some());
		let (amt, from, to, res) = result.unwrap();
		assert_eq!(amt, 100.0);
		assert_eq!(from, "USD");
		assert_eq!(to, "EUR");
		assert!(res > 0.0);
	}

	#[test]
	fn test_timezone_conversion() {
		let calc = Calculator::new();
		let result = calc.convert_timezone("3pm EST to PST");
		assert!(result.is_some());
	}
}
