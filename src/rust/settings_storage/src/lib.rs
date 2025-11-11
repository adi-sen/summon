use std::{io, path::Path};

use rkyv::{Archive, Deserialize, Serialize};
use storage_utils::RkyvStorage;

#[derive(Archive, Deserialize, Serialize, Debug, Clone)]
#[archive(compare(PartialEq))]
#[archive_attr(derive(Debug))]
pub struct AppSettings {
	pub theme:                    String,
	pub custom_font_name:         String,
	pub font_size:                String,
	pub max_results:              i32,
	pub max_clipboard_items:      i32,
	pub clipboard_retention_days: i32,
	pub quick_select_modifier:    String,
	pub enable_commands:          bool,
	pub show_tray_icon:           bool,
	pub show_dock_icon:           bool,
	pub hide_traffic_lights:      bool,
	pub launcher_shortcut_key:    String,
	pub launcher_shortcut_mods:   Vec<String>,
	pub clipboard_shortcut_key:   String,
	pub clipboard_shortcut_mods:  Vec<String>,
	pub search_folders:           Vec<String>,
}

impl Default for AppSettings {
	fn default() -> Self {
		Self {
			theme:                    "dark".to_string(),
			custom_font_name:         String::new(),
			font_size:                "medium".to_string(),
			max_results:              7,
			max_clipboard_items:      30,
			clipboard_retention_days: 7,
			quick_select_modifier:    "option".to_string(),
			enable_commands:          true,
			show_tray_icon:           true,
			show_dock_icon:           false,
			hide_traffic_lights:      false,
			launcher_shortcut_key:    "space".to_string(),
			launcher_shortcut_mods:   vec!["command".to_string()],
			clipboard_shortcut_key:   "v".to_string(),
			clipboard_shortcut_mods:  vec!["command".to_string(), "shift".to_string()],
			search_folders:           vec![
				"/Applications".to_string(),
				"/System/Applications".to_string(),
				"/System/Applications/Utilities".to_string(),
			],
		}
	}
}

pub struct SettingsStorage {
	storage: RkyvStorage<AppSettings>,
}

impl SettingsStorage {
	pub fn new<P: AsRef<Path>>(path: P) -> io::Result<Self> {
		let storage = RkyvStorage::new(path)?;
		if storage.is_empty() {
			storage.add(AppSettings::default())?;
		}
		Ok(Self { storage })
	}

	pub fn get(&self) -> AppSettings { self.storage.get_all().into_iter().next().unwrap_or_default() }

	pub fn save(&self, settings: AppSettings) -> io::Result<()> {
		self.storage.update(|entries| {
			entries.clear();
			entries.push(settings);
			true
		})?;
		Ok(())
	}
}

#[cfg(test)]
mod tests {
	use tempfile::NamedTempFile;

	use super::*;

	#[test]
	fn test_default_settings() {
		let temp = NamedTempFile::new().unwrap();
		let storage = SettingsStorage::new(temp.path()).unwrap();
		let settings = storage.get();
		assert_eq!(settings.theme, "dark");
		assert_eq!(settings.max_results, 7);
	}

	#[test]
	fn test_save_and_load() {
		let temp = NamedTempFile::new().unwrap();
		let storage = SettingsStorage::new(temp.path()).unwrap();

		let mut settings = storage.get();
		settings.theme = "light".to_string();
		settings.max_results = 10;
		storage.save(settings).unwrap();

		let storage2 = SettingsStorage::new(temp.path()).unwrap();
		let loaded = storage2.get();
		assert_eq!(loaded.theme, "light");
		assert_eq!(loaded.max_results, 10);
	}
}
