use rkyv::{Archive, Deserialize, Serialize};
use serde::{Deserialize as SerdeDeserialize, Serialize as SerdeSerialize};

#[derive(Archive, Deserialize, Serialize, SerdeSerialize, SerdeDeserialize, Debug, Clone, PartialEq)]
#[archive(compare(PartialEq))]
pub struct Action {
	pub id:      String,
	pub name:    String,
	pub icon:    String,
	pub enabled: bool,
	pub kind:    ActionKind,
}

#[derive(Archive, Deserialize, Serialize, SerdeSerialize, SerdeDeserialize, Debug, Clone, PartialEq)]
#[archive(compare(PartialEq))]
pub enum ActionKind {
	QuickLink { keyword: String, url: String },
	Pattern { pattern: String, action: PatternActionType },
	ScriptFilter { keyword: String, script_path: String, extension_dir: String },
	NativeExtension { keyword: String, extension_id: String },
}

#[derive(Archive, Deserialize, Serialize, SerdeSerialize, SerdeDeserialize, Debug, Clone, PartialEq)]
#[archive(compare(PartialEq))]
pub enum PatternActionType {
	OpenUrl(String),
	CopyText(String),
	RunCommand { cmd: String, args: Vec<String> },
}

#[derive(Debug, Clone, PartialEq)]
pub struct ActionResult {
	pub id:        String,
	pub title:     String,
	pub subtitle:  String,
	pub icon:      String,
	pub icon_path: Option<String>,
	pub score:     f32,
	pub action:    ResultAction,
	pub quicklook: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ResultAction {
	OpenUrl(String),
	CopyText(String),
	RunCommand { cmd: String, args: Vec<String> },
}

impl Action {
	pub fn quick_link(
		id: impl Into<String>,
		name: impl Into<String>,
		keyword: impl Into<String>,
		url: impl Into<String>,
		icon: impl Into<String>,
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
		id: impl Into<String>,
		name: impl Into<String>,
		pattern: impl Into<String>,
		action: PatternActionType,
		icon: impl Into<String>,
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
		id: impl Into<String>,
		name: impl Into<String>,
		keyword: impl Into<String>,
		script_path: impl Into<String>,
		extension_dir: impl Into<String>,
		icon: impl Into<String>,
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

	pub fn triggers(&self) -> Vec<&str> {
		match &self.kind {
			ActionKind::QuickLink { keyword, .. } => vec![keyword.as_str()],
			ActionKind::Pattern { pattern, .. } => {
				vec![pattern.split_whitespace().next().unwrap_or(pattern)]
			}
			ActionKind::ScriptFilter { keyword, .. } => vec![keyword.as_str()],
			ActionKind::NativeExtension { keyword, .. } => vec![keyword.as_str()],
		}
	}
}

impl ActionResult {
	pub fn new(
		id: impl Into<String>,
		title: impl Into<String>,
		subtitle: impl Into<String>,
		icon: impl Into<String>,
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

	pub fn with_icon_path(mut self, path: impl Into<String>) -> Self {
		self.icon_path = Some(path.into());
		self
	}

	pub fn with_quicklook(mut self, url: impl Into<String>) -> Self {
		self.quicklook = Some(url.into());
		self
	}
}
