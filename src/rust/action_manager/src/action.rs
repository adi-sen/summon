#![allow(clippy::used_underscore_binding)]

use bytecheck::CheckBytes;
use compact_str::CompactString;
use rkyv::{Archive, Deserialize, Serialize};
use serde::{Deserialize as SerdeDeserialize, Serialize as SerdeSerialize};

#[derive(Archive, Deserialize, Serialize, CheckBytes, SerdeSerialize, SerdeDeserialize, Debug, Clone, PartialEq)]
#[rkyv(derive(Debug))]
pub struct Action {
	pub id:      CompactString,
	pub name:    CompactString,
	pub icon:    CompactString,
	pub enabled: bool,
	pub kind:    ActionKind,
}

#[derive(
	Archive, Deserialize, Serialize, CheckBytes, SerdeSerialize, SerdeDeserialize, Debug, Clone, PartialEq, Eq,
)]
#[rkyv(derive(Debug))]
#[repr(u8)]
pub enum ActionKind {
	QuickLink { keyword: CompactString, url: CompactString },
	Pattern { pattern: CompactString, action: PatternActionType },
	ScriptFilter { keyword: CompactString, script_path: CompactString, extension_dir: CompactString },
}

#[derive(
	Archive, Deserialize, Serialize, CheckBytes, SerdeSerialize, SerdeDeserialize, Debug, Clone, PartialEq, Eq,
)]
#[rkyv(derive(Debug))]
#[repr(u8)]
pub enum PatternActionType {
	OpenUrl(String),
	CopyText(String),
	RunCommand { cmd: String, args: Vec<String> },
}

#[derive(Debug, Clone, PartialEq)]
pub struct ActionResult {
	pub id:        CompactString,
	pub title:     CompactString,
	pub subtitle:  CompactString,
	pub icon:      CompactString,
	pub icon_path: Option<CompactString>,
	pub score:     f32,
	pub action:    ResultAction,
	pub quicklook: Option<CompactString>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ResultAction {
	OpenUrl(String),
	CopyText(String),
	RunCommand { cmd: String, args: Vec<String> },
}

impl Action {
	pub fn quick_link(
		id: impl Into<CompactString>,
		name: impl Into<CompactString>,
		keyword: impl Into<CompactString>,
		url: impl Into<CompactString>,
		icon: impl Into<CompactString>,
	) -> Self {
		Self {
			id:      id.into(),
			name:    name.into(),
			icon:    icon.into(),
			enabled: true,
			kind:    ActionKind::QuickLink { keyword: keyword.into(), url: url.into() },
		}
	}

	pub fn pattern(
		id: impl Into<CompactString>,
		name: impl Into<CompactString>,
		pattern: impl Into<CompactString>,
		action: PatternActionType,
		icon: impl Into<CompactString>,
	) -> Self {
		Self {
			id:      id.into(),
			name:    name.into(),
			icon:    icon.into(),
			enabled: true,
			kind:    ActionKind::Pattern { pattern: pattern.into(), action },
		}
	}

	pub fn script_filter(
		id: impl Into<CompactString>,
		name: impl Into<CompactString>,
		keyword: impl Into<CompactString>,
		script_path: impl Into<CompactString>,
		extension_dir: impl Into<CompactString>,
		icon: impl Into<CompactString>,
	) -> Self {
		Self {
			id:      id.into(),
			name:    name.into(),
			icon:    icon.into(),
			enabled: true,
			kind:    ActionKind::ScriptFilter {
				keyword:       keyword.into(),
				script_path:   script_path.into(),
				extension_dir: extension_dir.into(),
			},
		}
	}

	#[must_use]
	pub fn triggers(&self) -> Vec<&str> {
		match &self.kind {
			ActionKind::QuickLink { keyword, .. } | ActionKind::ScriptFilter { keyword, .. } => vec![keyword.as_str()],
			ActionKind::Pattern { pattern, .. } => {
				vec![pattern.split_whitespace().next().unwrap_or(pattern)]
			}
		}
	}
}

impl ActionResult {
	pub fn new(
		id: impl Into<CompactString>,
		title: impl Into<CompactString>,
		subtitle: impl Into<CompactString>,
		icon: impl Into<CompactString>,
		score: f32,
		action: ResultAction,
	) -> Self {
		Self {
			id: id.into(),
			title: title.into(),
			subtitle: subtitle.into(),
			icon: icon.into(),
			icon_path: None,
			score,
			action,
			quicklook: None,
		}
	}

	#[must_use]
	pub fn with_icon_path(mut self, path: impl Into<CompactString>) -> Self {
		self.icon_path = Some(path.into());
		self
	}

	#[must_use]
	pub fn with_quicklook(mut self, url: impl Into<CompactString>) -> Self {
		self.quicklook = Some(url.into());
		self
	}
}
