import Foundation

struct Action: Codable, Identifiable {
	let id: String
	var name: String
	var icon: String
	var enabled: Bool
	var kind: ActionKind

	enum ActionKind: Codable {
		case quickLink(keyword: String, url: String)
		case pattern(pattern: String, url: String)
		case scriptFilter(keyword: String, scriptPath: String, extensionDir: String)
		case nativeExtension(keyword: String, extensionId: String)

		enum CodingKeys: String, CodingKey {
			case quickLink = "QuickLink"
			case pattern = "Pattern"
			case scriptFilter = "ScriptFilter"
			case nativeExtension = "NativeExtension"
		}

		private enum QuickLinkKeys: String, CodingKey {
			case keyword, url
		}

		private enum PatternKeys: String, CodingKey {
			case pattern, action
		}

		private enum PatternActionKeys: String, CodingKey {
			case openUrl = "OpenUrl"
		}

		private enum ScriptFilterKeys: String, CodingKey {
			case keyword
			case scriptPath = "script_path"
			case extensionDir = "extension_dir"
		}

		private enum NativeExtensionKeys: String, CodingKey {
			case keyword
			case extensionId = "extension_id"
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			if let quickLinkContainer = try? container
				.nestedContainer(keyedBy: QuickLinkKeys.self, forKey: .quickLink)
			{
				let keyword = try quickLinkContainer.decode(String.self, forKey: .keyword)
				let url = try quickLinkContainer.decode(String.self, forKey: .url)
				self = .quickLink(keyword: keyword, url: url)
			} else if let patternContainer = try? container.nestedContainer(
				keyedBy: PatternKeys.self,
				forKey: .pattern
			) {
				let pattern = try patternContainer.decode(String.self, forKey: .pattern)
				let actionContainer = try patternContainer.nestedContainer(
					keyedBy: PatternActionKeys.self,
					forKey: .action
				)
				let url = try actionContainer.decode(String.self, forKey: .openUrl)
				self = .pattern(pattern: pattern, url: url)
			} else if let scriptFilterContainer = try? container.nestedContainer(
				keyedBy: ScriptFilterKeys.self,
				forKey: .scriptFilter
			) {
				let keyword = try scriptFilterContainer.decode(String.self, forKey: .keyword)
				let scriptPath = try scriptFilterContainer.decode(String.self, forKey: .scriptPath)
				let extensionDir = try scriptFilterContainer.decode(String.self, forKey: .extensionDir)
				self = .scriptFilter(keyword: keyword, scriptPath: scriptPath, extensionDir: extensionDir)
			} else if let nativeExtContainer = try? container.nestedContainer(
				keyedBy: NativeExtensionKeys.self,
				forKey: .nativeExtension
			) {
				let keyword = try nativeExtContainer.decode(String.self, forKey: .keyword)
				let extensionId = try nativeExtContainer.decode(String.self, forKey: .extensionId)
				self = .nativeExtension(keyword: keyword, extensionId: extensionId)
			} else {
				throw DecodingError.dataCorrupted(
					DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown action kind")
				)
			}
		}

		func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)

			switch self {
			case let .quickLink(keyword, url):
				var quickLinkContainer = container.nestedContainer(keyedBy: QuickLinkKeys.self, forKey: .quickLink)
				try quickLinkContainer.encode(keyword, forKey: .keyword)
				try quickLinkContainer.encode(url, forKey: .url)

			case let .pattern(pattern, url):
				var patternContainer = container.nestedContainer(keyedBy: PatternKeys.self, forKey: .pattern)
				try patternContainer.encode(pattern, forKey: .pattern)
				var actionContainer = patternContainer.nestedContainer(keyedBy: PatternActionKeys.self, forKey: .action)
				try actionContainer.encode(url, forKey: .openUrl)

			case let .scriptFilter(keyword, scriptPath, extensionDir):
				var scriptFilterContainer = container.nestedContainer(
					keyedBy: ScriptFilterKeys.self,
					forKey: .scriptFilter
				)
				try scriptFilterContainer.encode(keyword, forKey: .keyword)
				try scriptFilterContainer.encode(scriptPath, forKey: .scriptPath)
				try scriptFilterContainer.encode(extensionDir, forKey: .extensionDir)

			case let .nativeExtension(keyword, extensionId):
				var nativeExtContainer = container.nestedContainer(
					keyedBy: NativeExtensionKeys.self,
					forKey: .nativeExtension
				)
				try nativeExtContainer.encode(keyword, forKey: .keyword)
				try nativeExtContainer.encode(extensionId, forKey: .extensionId)
			}
		}
	}
}

final class ActionManager: ObservableObject {
	static let shared = ActionManager()

	@Published var actions: [Action] = []

	private let handle: FFIHandle<OpaquePointer>

	init() {
		let storagePath = StoragePathManager.shared.getActionsPath()
		handle = FFIHandle(
			create: { FFI.actionManagerNew(path: storagePath) },
			free: FFI.actionManagerFree
		)
		load()
	}

	func load() {
		guard let json = FFI.actionManagerGetAllJSON(handle.handle) else {
			importDefaults()
			return
		}

		guard let data = json.data(using: .utf8),
		      let decoded = try? JSONDecoder().decode([Action].self, from: data)
		else {
			importDefaults()
			return
		}

		actions = decoded

		if actions.isEmpty {
			importDefaults()
		}

		importOrphanedExtensions()
		importNativeExtensions()
	}

	private func importOrphanedExtensions() {
		let extensionsDir = StoragePathManager.shared.getExtensionsDir()
		guard let directoryURLs = try? FileManager.default.contentsOfDirectory(
			at: URL(fileURLWithPath: extensionsDir),
			includingPropertiesForKeys: [.isDirectoryKey],
			options: [.skipsHiddenFiles]
		) else { return }

		for dirURL in directoryURLs {
			guard (try? dirURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
				continue
			}

			let manifestPath = dirURL.appendingPathComponent("manifest.json").path

			guard FileManager.default.fileExists(atPath: manifestPath) else {
				continue
			}

			guard let manifestData = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
			      let manifest = try? JSONDecoder().decode(ExtensionManifest.self, from: manifestData)
			else {
				print("Failed to parse manifest at: \(manifestPath)")
				continue
			}

			let extensionId = dirURL.lastPathComponent

			if actions.contains(where: { $0.id == extensionId }) {
				continue
			}

			let scriptPath = dirURL.appendingPathComponent(manifest.script).path

			guard FileManager.default.fileExists(atPath: scriptPath) else {
				print("Script not found: \(scriptPath)")
				continue
			}

			var iconPath = "puzzlepiece.extension"
			if let iconFile = manifest.icon {
				let fullIconPath = dirURL.appendingPathComponent(iconFile).path
				if FileManager.default.fileExists(atPath: fullIconPath) {
					iconPath = fullIconPath
				}
			}

			let action = Action(
				id: extensionId,
				name: manifest.name,
				icon: iconPath,
				enabled: true,
				kind: .scriptFilter(
					keyword: manifest.keyword,
					scriptPath: scriptPath,
					extensionDir: dirURL.path
				)
			)

			print("Auto-importing extension: \(manifest.name) (keyword: \(manifest.keyword))")
			add(action)
		}
	}

	private func importNativeExtensions() {
		// Native extensions can be registered here if needed
		// Example:
		// let nativeExtensions: [(id: String, name: String, keyword: String, icon: String)] = [
		//     ("my-native-extension", "My Extension", "mye", "star.fill")
		// ]
		// Currently empty - native extensions should be rare and only for performance-critical features
	}

	func importDefaults() {
		_ = FFI.actionManagerImportDefaults(handle.handle)
		load()
	}

	func add(_ action: Action) {
		guard let json = try? JSONEncoder().encode(action),
		      let jsonString = String(data: json, encoding: .utf8)
		else { return }

		if FFI.actionManagerAddJSON(handle.handle, json: jsonString) {
			load()
		}
	}

	func addQuickLink(id: String, name: String, keyword: String, url: String, icon: String) {
		if FFI.actionManagerAddQuickLink(handle.handle, id: id, name: name, keyword: keyword, url: url, icon: icon) {
			load()
		}
	}

	func addPattern(id: String, name: String, pattern: String, url: String, icon: String) {
		if FFI.actionManagerAddPattern(handle.handle, id: id, name: name, pattern: pattern, url: url, icon: icon) {
			load()
		}
	}

	func update(_ action: Action) {
		guard let json = try? JSONEncoder().encode(action),
		      let jsonString = String(data: json, encoding: .utf8)
		else { return }

		if FFI.actionManagerUpdateJSON(handle.handle, json: jsonString) {
			load()
		}
	}

	func remove(_ action: Action) {
		if FFI.actionManagerRemove(handle.handle, id: action.id) {
			load()
		}
	}

	func toggle(_ action: Action) {
		if FFI.actionManagerToggle(handle.handle, id: action.id) {
			load()
		}
	}

	func search(query: String) -> [FFI.SwiftActionResult] {
		let results = FFI.actionManagerSearch(handle.handle, query: query)
		return results
	}
}
