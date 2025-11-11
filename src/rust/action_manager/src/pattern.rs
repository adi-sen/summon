use std::collections::HashMap;

use crate::action::{ActionResult, PatternActionType, ResultAction};

pub fn match_pattern(pattern: &str, input: &str) -> Option<HashMap<String, String>> {
	let mut captures = HashMap::new();
	let pattern_parts: Vec<_> = pattern.split_whitespace().collect();
	let input_parts: Vec<_> = input.split_whitespace().collect();

	if pattern_parts.len() != input_parts.len() {
		return None;
	}

	for (pat, inp) in pattern_parts.iter().zip(input_parts.iter()) {
		if pat.contains('{') {
			let mut pat_idx = 0;
			let mut inp_idx = 0;
			let pat_bytes = pat.as_bytes();
			let inp_bytes = inp.as_bytes();

			while pat_idx < pat_bytes.len() {
				if pat_bytes[pat_idx] == b'{' {
					let var_start = pat_idx + 1;
					let var_end = pat.bytes().skip(var_start).position(|b| b == b'}').map(|p| var_start + p);

					if let Some(var_end) = var_end {
						let var_name = &pat[var_start..var_end];

						let next_literal_idx = var_end + 1;
						let value_end = if next_literal_idx < pat_bytes.len() {
							let next_literal = pat_bytes[next_literal_idx];
							inp_bytes
								.iter()
								.skip(inp_idx)
								.position(|&b| b == next_literal)
								.map(|p| inp_idx + p)
								.unwrap_or(inp_bytes.len())
						} else {
							inp_bytes.len()
						};

						if value_end > inp_idx {
							let value = &inp[inp_idx..value_end];
							captures.insert(var_name.to_string(), value.to_string());
							inp_idx = value_end;
							pat_idx = next_literal_idx;
						} else {
							return None;
						}
					} else {
						return None;
					}
				} else {
					if pat_idx >= pat_bytes.len() || inp_idx >= inp_bytes.len() {
						return None;
					}
					if pat_bytes[pat_idx] != inp_bytes[inp_idx] {
						return None;
					}
					pat_idx += 1;
					inp_idx += 1;
				}
			}

			if inp_idx != inp_bytes.len() {
				return None;
			}
		} else if pat != inp {
			return None;
		}
	}

	Some(captures)
}

pub fn expand_template(template: &str, captures: &HashMap<String, String>) -> String {
	let mut result = template.to_string();

	for (key, value) in captures {
		result = result.replace(&format!("{{{}}}", key), value);
	}

	result
}

pub fn create_result(
	action_id: &str,
	_action_name: &str,
	pattern: &str,
	action_type: &PatternActionType,
	captures: &HashMap<String, String>,
	icon: &str,
) -> ActionResult {
	let title = expand_template(pattern, captures);

	let result_action = match action_type {
		PatternActionType::OpenUrl(url) => {
			let expanded_url = expand_template(url, captures);
			ResultAction::OpenUrl(expanded_url)
		}
		PatternActionType::CopyText(text) => {
			let expanded_text = expand_template(text, captures);
			ResultAction::CopyText(expanded_text)
		}
		PatternActionType::RunCommand { cmd, args } => {
			let expanded_cmd = expand_template(cmd, captures);
			let expanded_args = args.iter().map(|arg| expand_template(arg, captures)).collect();
			ResultAction::RunCommand { cmd: expanded_cmd, args: expanded_args }
		}
	};

	let subtitle = match &result_action {
		ResultAction::OpenUrl(url) => url.clone(),
		ResultAction::CopyText(text) => format!("Copy: {}", text),
		ResultAction::RunCommand { cmd, args } => format!("Run: {} {}", cmd, args.join(" ")),
	};

	ActionResult::new(format!("{}:{}", action_id, title), title, subtitle, icon, 95.0, result_action)
}
