use std::{collections::HashMap, sync::Arc};

use parking_lot::RwLock;

use crate::action::ActionResult;

pub trait NativeExtension: Send + Sync {
	fn id(&self) -> &str;
	fn search(&self, query: &str) -> Vec<ActionResult>;
	fn reload(&mut self);
}

pub struct ExtensionRegistry {
	extensions: HashMap<String, Arc<RwLock<Box<dyn NativeExtension>>>>,
}

impl ExtensionRegistry {
	pub fn new() -> Self { Self { extensions: HashMap::new() } }

	pub fn register(&mut self, extension: Box<dyn NativeExtension>) {
		let id = extension.id().to_string();
		self.extensions.insert(id, Arc::new(RwLock::new(extension)));
	}

	pub fn search(&self, extension_id: &str, query: &str) -> Vec<ActionResult> {
		if let Some(ext) = self.extensions.get(extension_id) { ext.read().search(query) } else { vec![] }
	}

	pub fn reload(&self, extension_id: &str) {
		if let Some(ext) = self.extensions.get(extension_id) {
			ext.write().reload();
		}
	}

	pub fn reload_all(&self) {
		for ext in self.extensions.values() {
			ext.write().reload();
		}
	}
}

impl Default for ExtensionRegistry {
	fn default() -> Self { Self::new() }
}

// Example native extension implementation:
//
// struct MyExtension {
//     data: Vec<SomeData>,
// }
//
// impl NativeExtension for MyExtension {
//     fn id(&self) -> &str { "my-extension" }
//
//     fn search(&self, query: &str) -> Vec<ActionResult> {
//         // Implementation
//         vec![]
//     }
//
//     fn reload(&mut self) {
//         // Reload data
//     }
// }
