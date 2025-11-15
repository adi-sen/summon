// swiftlint:disable function_parameter_count
import Foundation

enum FFI {
	typealias ClipboardStorageHandle = OpaquePointer

	struct SwiftClipboardEntry {
		let content: String
		let timestamp: Double
		let itemType: UInt8
		let imageFilePath: String?
		let imageWidth: Double
		let imageHeight: Double
		let size: Int32
		let sourceApp: String?
	}

	static func clipboardStorageNew(path: String) -> ClipboardStorageHandle? {
		clipboard_storage_new(path)
	}

	static func clipboardStorageFree(_ handle: ClipboardStorageHandle?) {
		guard let handle else { return }
		clipboard_storage_free(handle)
	}

	static func clipboardStorageAddText(
		_ handle: ClipboardStorageHandle?,
		content: String,
		timestamp: Double,
		size: Int32,
		sourceApp: String?
	) -> Bool {
		guard let handle else { return false }
		return clipboard_storage_add_text(handle, content, timestamp, size, sourceApp)
	}

	static func clipboardStorageAddImage(
		_ handle: ClipboardStorageHandle?,
		content: String,
		timestamp: Double,
		imageFilePath: String,
		width: Double,
		height: Double,
		size: Int32,
		sourceApp: String?
	) -> Bool {
		guard let handle else { return false }
		return clipboard_storage_add_image(
			handle,
			content,
			timestamp,
			imageFilePath,
			width,
			height,
			size,
			sourceApp
		)
	}

	static func clipboardStorageGetEntries(
		_ handle: ClipboardStorageHandle?,
		start: Int,
		count: Int
	) -> [SwiftClipboardEntry] {
		guard let handle else { return [] }

		var outCount = 0
		guard let cEntries = clipboard_storage_get_entries(handle, start, count, &outCount),
		      outCount > 0
		else {
			return []
		}

		var swiftEntries: [SwiftClipboardEntry] = []
		swiftEntries.reserveCapacity(outCount)

		for i in 0 ..< outCount {
			let cEntry = cEntries[i]

			guard let content = FFIHelpers.safeString(from: cEntry.content) else { continue }

			swiftEntries.append(
				SwiftClipboardEntry(
					content: content,
					timestamp: cEntry.timestamp,
					itemType: cEntry.item_type,
					imageFilePath: FFIHelpers.safeString(from: cEntry.image_file_path),
					imageWidth: cEntry.image_width,
					imageHeight: cEntry.image_height,
					size: cEntry.size,
					sourceApp: FFIHelpers.safeString(from: cEntry.source_app)
				))
		}

		clipboard_entries_free(cEntries, outCount)

		return swiftEntries
	}

	static func clipboardStorageLen(_ handle: ClipboardStorageHandle?) -> Int {
		guard let handle else { return 0 }
		return clipboard_storage_len(handle)
	}

	static func clipboardStorageTrim(_ handle: ClipboardStorageHandle?, maxEntries: Int) -> Bool {
		guard let handle else { return false }
		return clipboard_storage_trim(handle, maxEntries)
	}

	static func clipboardStorageClear(_ handle: ClipboardStorageHandle?) -> Bool {
		guard let handle else { return false }
		return clipboard_storage_clear(handle)
	}

	static func clipboardStorageRemoveAt(_ handle: ClipboardStorageHandle?, index: Int32) -> Bool {
		guard let handle else { return false }
		return clipboard_storage_remove_at(handle, index)
	}

	typealias SnippetStorageHandle = OpaquePointer

	struct SwiftSnippet {
		let id: String
		let trigger: String
		let content: String
		let enabled: Bool
		let category: String
	}

	static func snippetStorageNew(path: String) -> SnippetStorageHandle? {
		snippet_storage_new(path)
	}

	static func snippetStorageFree(_ handle: SnippetStorageHandle?) {
		guard let handle else { return }
		snippet_storage_free(handle)
	}

	static func snippetStorageAdd(
		_ handle: SnippetStorageHandle?,
		id: String,
		trigger: String,
		content: String,
		enabled: Bool,
		category: String
	) -> Bool {
		guard let handle else { return false }
		return snippet_storage_add(handle, id, trigger, content, enabled, category)
	}

	static func snippetStorageUpdate(
		_ handle: SnippetStorageHandle?,
		id: String,
		trigger: String,
		content: String,
		enabled: Bool,
		category: String
	) -> Bool {
		guard let handle else { return false }
		return snippet_storage_update(handle, id, trigger, content, enabled, category)
	}

	static func snippetStorageDelete(_ handle: SnippetStorageHandle?, id: String) -> Bool {
		guard let handle else { return false }
		return snippet_storage_delete(handle, id)
	}

	static func snippetStorageGetAll(_ handle: SnippetStorageHandle?) -> [SwiftSnippet] {
		guard let handle else { return [] }

		var outCount = 0
		guard let cSnippets = snippet_storage_get_all(handle, &outCount),
		      outCount > 0
		else {
			return []
		}

		let swiftSnippets = convertCSnippetsToSwift(cSnippets, count: outCount)
		snippets_free(cSnippets, outCount)

		return swiftSnippets
	}

	static func snippetStorageGetEnabled(_ handle: SnippetStorageHandle?) -> [SwiftSnippet] {
		guard let handle else { return [] }

		var outCount = 0
		guard let cSnippets = snippet_storage_get_enabled(handle, &outCount),
		      outCount > 0
		else {
			return []
		}

		let swiftSnippets = convertCSnippetsToSwift(cSnippets, count: outCount)
		snippets_free(cSnippets, outCount)

		return swiftSnippets
	}

	static func snippetStorageLen(_ handle: SnippetStorageHandle?) -> Int {
		guard let handle else { return 0 }
		return snippet_storage_len(handle)
	}

	static func cStringToSwift(_ ptr: UnsafeMutablePointer<CChar>?) -> String? {
		FFIHelpers.safeString(from: ptr)
	}

	private static func convertCSnippetsToSwift(
		_ cSnippets: UnsafeMutablePointer<CSnippet>,
		count: Int
	) -> [SwiftSnippet] {
		var swiftSnippets: [SwiftSnippet] = []
		swiftSnippets.reserveCapacity(count)

		for i in 0 ..< count {
			let cSnippet = cSnippets[i]

			guard let id = FFIHelpers.safeString(from: cSnippet.id),
			      let trigger = FFIHelpers.safeString(from: cSnippet.trigger),
			      let content = FFIHelpers.safeString(from: cSnippet.content),
			      let category = FFIHelpers.safeString(from: cSnippet.category)
			else { continue }

			swiftSnippets.append(
				SwiftSnippet(
					id: id,
					trigger: trigger,
					content: content,
					enabled: cSnippet.enabled,
					category: category
				))
		}

		return swiftSnippets
	}

	typealias AppStorageHandle = OpaquePointer

	struct CAppEntry {
		let name: UnsafeMutablePointer<CChar>?
		let path: UnsafeMutablePointer<CChar>?
	}

	struct SwiftAppEntry {
		let name: String
		let path: String
	}

	typealias SettingsStorageHandle = OpaquePointer

	struct SwiftAppSettings {
		let theme: String
		let customFontName: String
		let fontSize: String
		let maxResults: Int
		let maxClipboardItems: Int
		let clipboardRetentionDays: Int
		let quickSelectModifier: String
		let enableCommands: Bool
		let showTrayIcon: Bool
		let showDockIcon: Bool
		let hideTrafficLights: Bool
		let launcherShortcutKey: String
		let launcherShortcutMods: [String]
		let clipboardShortcutKey: String
		let clipboardShortcutMods: [String]
		let searchFolders: [String]
	}

	static func appStorageNew(path: String) -> AppStorageHandle? {
		app_storage_new(path)
	}

	static func appStorageFree(_ handle: AppStorageHandle?) {
		guard let handle else { return }
		app_storage_free(handle)
	}

	static func appStorageAdd(_ handle: AppStorageHandle?, name: String, path: String) -> Bool {
		guard let handle else { return false }
		return app_storage_add(handle, name, path)
	}

	static func appStorageGetAll(_ handle: AppStorageHandle?) -> [SwiftAppEntry] {
		guard let handle else { return [] }

		var outCount = 0
		guard let cEntries = app_storage_get_all(handle, &outCount), outCount > 0 else {
			return []
		}

		var swiftEntries: [SwiftAppEntry] = []
		swiftEntries.reserveCapacity(outCount)

		for i in 0 ..< outCount {
			let cEntry = cEntries[i]
			guard let name = FFIHelpers.safeString(from: cEntry.name),
			      let path = FFIHelpers.safeString(from: cEntry.path)
			else { continue }

			swiftEntries.append(SwiftAppEntry(name: name, path: path))
		}

		app_entries_free(cEntries, outCount)
		return swiftEntries
	}

	static func appStorageLen(_ handle: AppStorageHandle?) -> Int {
		guard let handle else { return 0 }
		return app_storage_len(handle)
	}

	static func appStorageClear(_ handle: AppStorageHandle?) -> Bool {
		guard let handle else { return false }
		return app_storage_clear(handle)
	}

	static func settingsStorageNew(path: String) -> SettingsStorageHandle? {
		settings_storage_new(path)
	}

	static func settingsStorageFree(_ handle: SettingsStorageHandle?) {
		guard let handle else { return }
		settings_storage_free(handle)
	}

	static func settingsStorageGet(_ handle: SettingsStorageHandle?) -> SwiftAppSettings? {
		guard let handle else { return nil }
		guard let cSettings = settings_storage_get(handle) else { return nil }

		defer { settings_free(cSettings) }

		let theme = FFIHelpers.safeString(from: cSettings.pointee.theme) ?? "dark"
		let customFontName = FFIHelpers.safeString(from: cSettings.pointee.custom_font_name) ?? ""
		let fontSize = FFIHelpers.safeString(from: cSettings.pointee.font_size) ?? "medium"
		let quickSelectModifier = FFIHelpers.safeString(from: cSettings.pointee.quick_select_modifier) ?? "option"

		var launcherShortcut = ("space", ["command"])
		if let jsonPtr = settings_storage_get_launcher_shortcut(handle) {
			defer { calculator_free_string(jsonPtr) }
			if let jsonStr = FFIHelpers.safeString(from: jsonPtr),
			   let data = jsonStr.data(using: .utf8),
			   let dict = try? JSONDecoder().decode([String: [String]].self, from: data),
			   let key = dict["key"]?.first,
			   let mods = dict["modifiers"]
			{
				launcherShortcut = (key, mods)
			}
		}

		var clipboardShortcut = ("v", ["command", "shift"])
		if let jsonPtr = settings_storage_get_clipboard_shortcut(handle) {
			defer { calculator_free_string(jsonPtr) }
			if let jsonStr = FFIHelpers.safeString(from: jsonPtr),
			   let data = jsonStr.data(using: .utf8),
			   let dict = try? JSONDecoder().decode([String: [String]].self, from: data),
			   let key = dict["key"]?.first,
			   let mods = dict["modifiers"]
			{
				clipboardShortcut = (key, mods)
			}
		}

		var searchFolders = ["/Applications", "/System/Applications", "/System/Applications/Utilities"]
		if let jsonPtr = settings_storage_get_search_folders(handle) {
			defer { calculator_free_string(jsonPtr) }
			if let jsonStr = FFIHelpers.safeString(from: jsonPtr),
			   let data = jsonStr.data(using: .utf8),
			   let arr = try? JSONDecoder().decode([String].self, from: data)
			{
				searchFolders = arr
			}
		}

		return SwiftAppSettings(
			theme: theme,
			customFontName: customFontName,
			fontSize: fontSize,
			maxResults: Int(cSettings.pointee.max_results),
			maxClipboardItems: Int(cSettings.pointee.max_clipboard_items),
			clipboardRetentionDays: Int(cSettings.pointee.clipboard_retention_days),
			quickSelectModifier: quickSelectModifier,
			enableCommands: cSettings.pointee.enable_commands,
			showTrayIcon: cSettings.pointee.show_tray_icon,
			showDockIcon: cSettings.pointee.show_dock_icon,
			hideTrafficLights: cSettings.pointee.hide_traffic_lights,
			launcherShortcutKey: launcherShortcut.0,
			launcherShortcutMods: launcherShortcut.1,
			clipboardShortcutKey: clipboardShortcut.0,
			clipboardShortcutMods: clipboardShortcut.1,
			searchFolders: searchFolders
		)
	}

	// swiftlint:disable:next function_parameter_count
	static func settingsStorageSave(
		_ handle: SettingsStorageHandle?,
		theme: String,
		customFontName: String,
		fontSize: String,
		maxResults: Int,
		maxClipboardItems: Int,
		clipboardRetentionDays: Int,
		quickSelectModifier: String,
		enableCommands: Bool,
		showTrayIcon: Bool,
		showDockIcon: Bool,
		hideTrafficLights: Bool,
		launcherShortcutKey: String,
		launcherShortcutMods: [String],
		clipboardShortcutKey: String,
		clipboardShortcutMods: [String],
		searchFolders: [String]
	) -> Bool {
		guard let handle else { return false }

		guard let launcherModsJSON = try? JSONEncoder().encode(launcherShortcutMods),
		      let launcherModsStr = String(data: launcherModsJSON, encoding: .utf8),
		      let clipboardModsJSON = try? JSONEncoder().encode(clipboardShortcutMods),
		      let clipboardModsStr = String(data: clipboardModsJSON, encoding: .utf8),
		      let foldersJSON = try? JSONEncoder().encode(searchFolders),
		      let foldersStr = String(data: foldersJSON, encoding: .utf8)
		else { return false }

		return settings_storage_save(
			handle,
			theme,
			customFontName,
			fontSize,
			Int32(maxResults),
			Int32(maxClipboardItems),
			Int32(clipboardRetentionDays),
			quickSelectModifier,
			enableCommands,
			showTrayIcon,
			showDockIcon,
			hideTrafficLights,
			launcherShortcutKey,
			launcherModsStr,
			clipboardShortcutKey,
			clipboardModsStr,
			foldersStr
		)
	}

	typealias CalculatorHandle = OpaquePointer

	static func calculatorNew() -> CalculatorHandle? {
		calculator_new()
	}

	static func calculatorFree(_ handle: CalculatorHandle?) {
		guard let handle else { return }
		calculator_free(handle)
	}

	static func calculatorEvaluate(_ handle: CalculatorHandle?, query: String) -> String? {
		guard let handle else { return nil }

		let result = query.withCString { queryPtr in
			calculator_evaluate(handle, queryPtr)
		}

		guard let result else { return nil }

		defer { calculator_free_string(result) }
		return String(cString: result)
	}

	static func calculatorGetHistoryJSON(_ handle: CalculatorHandle?) -> String? {
		guard let handle else { return nil }

		let json = calculator_get_history_json(handle)
		guard let json else { return nil }

		defer { calculator_free_string(json) }
		return String(cString: json)
	}

	static func calculatorClearHistory(_ handle: CalculatorHandle?) {
		guard let handle else { return }
		calculator_clear_history(handle)
	}

	typealias SearchEngineHandle = OpaquePointer

	static func searchEngineNew() -> SearchEngineHandle? {
		search_engine_new()
	}

	static func searchEngineFree(_ handle: SearchEngineHandle?) {
		guard let handle else { return }
		search_engine_free(handle)
	}

	static func searchEngineAddItem(
		_ handle: SearchEngineHandle?,
		id: String,
		name: String,
		path: String,
		itemType: Int32
	) -> Bool {
		guard let handle else { return false }
		return id.withCString { idPtr in
			name.withCString { namePtr in
				path.withCString { pathPtr in
					search_engine_add_item(handle, idPtr, namePtr, pathPtr, itemType)
				}
			}
		}
	}

	static func searchEngineSearch(
		_ handle: SearchEngineHandle?,
		query: String,
		limit: Int
	) -> [(id: String, name: String, path: String?, score: Int64)] {
		guard let handle, !query.isEmpty else { return [] }

		var count = 0
		let results = query.withCString { queryPtr in
			search_engine_search(handle, queryPtr, limit, &count)
		}

		guard let results, count > 0 else { return [] }
		defer { search_results_free(results, count) }

		var output: [(id: String, name: String, path: String?, score: Int64)] = []
		for i in 0 ..< count {
			let result = results[i]
			let id = FFIHelpers.safeString(from: result.id) ?? ""
			let name = FFIHelpers.safeString(from: result.name) ?? ""
			let path = FFIHelpers.safeString(from: result.path)
			output.append((id: id, name: name, path: path, score: result.score))
		}
		return output
	}

	static func searchEngineStats(_ handle: SearchEngineHandle?) -> (
		total: Int, apps: Int, files: Int, snippets: Int
	) {
		guard let handle else { return (0, 0, 0, 0) }
		var total = 0
		var apps = 0
		var files = 0
		var snippets = 0
		_ = search_engine_stats(handle, &total, &apps, &files, &snippets)
		return (total, apps, files, snippets)
	}

	static func searchEngineScanApps(
		_ handle: SearchEngineHandle?,
		directories: [String],
		excludePatterns: [String]
	) -> Int {
		guard let handle else { return 0 }

		var dirPointers = directories.map { strdup($0) }
		defer { dirPointers.forEach { free($0) } }

		var excludePointers = excludePatterns.map { strdup($0) }
		defer { excludePointers.forEach { free($0) } }

		return dirPointers.withUnsafeMutableBufferPointer { dirBuffer in
			excludePointers.withUnsafeMutableBufferPointer { excludeBuffer in
				let dirCArray = CStringArray(data: dirBuffer.baseAddress, len: dirBuffer.count)
				let excludeCArray = CStringArray(
					data: excludeBuffer.baseAddress, len: excludeBuffer.count
				)
				return search_engine_scan_apps(handle, dirCArray, excludeCArray)
			}
		}
	}

	static func searchEngineGetApps(_ handle: SearchEngineHandle?) -> [(name: String, path: String)] {
		guard let handle else { return [] }

		var count = 0
		guard let entries = search_engine_get_apps(handle, &count), count > 0 else {
			return []
		}

		var apps: [(name: String, path: String)] = []
		apps.reserveCapacity(count)

		for i in 0 ..< count {
			let entry = entries[i]
			guard let name = FFIHelpers.safeString(from: entry.name),
			      let path = FFIHelpers.safeString(from: entry.path)
			else { continue }
			apps.append((name, path))
		}

		indexed_apps_free(entries, count)
		return apps
	}

	static func searchEngineEnableFileSearch(
		_ handle: SearchEngineHandle?,
		directories: [String],
		extensions: [String]
	) {
		guard let handle else { return }

		var dirPointers = directories.map { strdup($0) }
		defer { dirPointers.forEach { free($0) } }

		var extPointers = extensions.map { strdup($0) }
		defer { extPointers.forEach { free($0) } }

		dirPointers.withUnsafeMutableBufferPointer { dirBuffer in
			extPointers.withUnsafeMutableBufferPointer { extBuffer in
				let dirCArray = CStringArray(data: dirBuffer.baseAddress, len: dirBuffer.count)
				let extCArray = CStringArray(data: extBuffer.baseAddress, len: extBuffer.count)
				search_engine_enable_file_search(handle, dirCArray, extCArray)
			}
		}
	}

	static func searchEngineDisableFileSearch(_ handle: SearchEngineHandle?) {
		guard let handle else { return }
		search_engine_disable_file_search(handle)
	}

	typealias SnippetMatcherHandle = OpaquePointer

	static func snippetMatcherNew() -> SnippetMatcherHandle? {
		snippet_matcher_new()
	}

	static func snippetMatcherFree(_ handle: SnippetMatcherHandle?) {
		guard let handle else { return }
		snippet_matcher_free(handle)
	}

	static func snippetMatcherUpdate(_ handle: SnippetMatcherHandle?, json: String) -> Bool {
		guard let handle else { return false }
		return json.withCString { snippet_matcher_update(handle, $0) }
	}

	static func snippetMatcherFind(_ handle: SnippetMatcherHandle?, text: String) -> (
		trigger: String, content: String, matchEnd: Int
	)? {
		guard let handle else { return nil }
		return text.withCString { cString -> (String, String, Int)? in
			guard let result = snippet_matcher_find(handle, cString) else { return nil }
			defer { snippet_match_free(result) }
			guard let trigger = FFIHelpers.safeString(from: result.pointee.trigger),
			      let content = FFIHelpers.safeString(from: result.pointee.content)
			else { return nil }
			return (trigger, content, trigger.count)
		}
	}
}

struct CSearchResult {
	var id: UnsafeMutablePointer<CChar>?
	var name: UnsafeMutablePointer<CChar>?
	var path: UnsafeMutablePointer<CChar>?
	var score: Int64
}

struct CSnippetMatch {
	var trigger: UnsafeMutablePointer<CChar>?
	var content: UnsafeMutablePointer<CChar>?
	var matchEnd: Int
}

@_silgen_name("calculator_clear_history")
func calculator_clear_history(_ handle: OpaquePointer?)

@_silgen_name("calculator_free_string")
func calculator_free_string(_ s: UnsafeMutablePointer<CChar>?)

@_silgen_name("clipboard_storage_new")
func clipboard_storage_new(_ path: UnsafePointer<CChar>?) -> OpaquePointer?

@_silgen_name("clipboard_storage_free")
func clipboard_storage_free(_ handle: OpaquePointer?)

@_silgen_name("clipboard_storage_add_text")
func clipboard_storage_add_text(
	_ handle: OpaquePointer?,
	_ content: UnsafePointer<CChar>?,
	_ timestamp: Double,
	_ size: Int32,
	_ sourceApp: UnsafePointer<CChar>?
) -> Bool

@_silgen_name("clipboard_storage_add_image")
func clipboard_storage_add_image(
	_ handle: OpaquePointer?,
	_ content: UnsafePointer<CChar>?,
	_ timestamp: Double,
	_ imageFilePath: UnsafePointer<CChar>?,
	_ width: Double,
	_ height: Double,
	_ size: Int32,
	_ sourceApp: UnsafePointer<CChar>?
) -> Bool

@_silgen_name("clipboard_storage_get_entries")
func clipboard_storage_get_entries(
	_ handle: OpaquePointer?,
	_ start: Int,
	_ count: Int,
	_ outCount: UnsafeMutablePointer<Int>?
) -> UnsafeMutablePointer<CClipboardEntry>?

@_silgen_name("clipboard_storage_len")
func clipboard_storage_len(_ handle: OpaquePointer?) -> Int

@_silgen_name("clipboard_storage_trim")
func clipboard_storage_trim(_ handle: OpaquePointer?, _ maxEntries: Int) -> Bool

@_silgen_name("clipboard_storage_clear")
func clipboard_storage_clear(_ handle: OpaquePointer?) -> Bool

@_silgen_name("clipboard_storage_remove_at")
func clipboard_storage_remove_at(_ handle: OpaquePointer?, _ index: Int32) -> Bool

@_silgen_name("clipboard_entries_free")
func clipboard_entries_free(
	_ entries: UnsafeMutablePointer<CClipboardEntry>?,
	_ count: Int
)

@_silgen_name("snippet_storage_new")
func snippet_storage_new(_ path: UnsafePointer<CChar>?) -> OpaquePointer?

@_silgen_name("snippet_storage_free")
func snippet_storage_free(_ handle: OpaquePointer?)

@_silgen_name("snippet_storage_add")
func snippet_storage_add(
	_ handle: OpaquePointer?,
	_ id: UnsafePointer<CChar>?,
	_ trigger: UnsafePointer<CChar>?,
	_ content: UnsafePointer<CChar>?,
	_ enabled: Bool,
	_ category: UnsafePointer<CChar>?
) -> Bool

@_silgen_name("snippet_storage_update")
func snippet_storage_update(
	_ handle: OpaquePointer?,
	_ id: UnsafePointer<CChar>?,
	_ trigger: UnsafePointer<CChar>?,
	_ content: UnsafePointer<CChar>?,
	_ enabled: Bool,
	_ category: UnsafePointer<CChar>?
) -> Bool

@_silgen_name("snippet_storage_delete")
func snippet_storage_delete(
	_ handle: OpaquePointer?,
	_ id: UnsafePointer<CChar>?
) -> Bool

@_silgen_name("snippet_storage_get_all")
func snippet_storage_get_all(
	_ handle: OpaquePointer?,
	_ outCount: UnsafeMutablePointer<Int>?
) -> UnsafeMutablePointer<CSnippet>?

@_silgen_name("snippet_storage_get_enabled")
func snippet_storage_get_enabled(
	_ handle: OpaquePointer?,
	_ outCount: UnsafeMutablePointer<Int>?
) -> UnsafeMutablePointer<CSnippet>?

@_silgen_name("snippet_storage_len")
func snippet_storage_len(_ handle: OpaquePointer?) -> Int

@_silgen_name("snippets_free")
func snippets_free(
	_ snippets: UnsafeMutablePointer<CSnippet>?,
	_ count: Int
)

@_silgen_name("search_engine_new")
func search_engine_new() -> OpaquePointer?

@_silgen_name("search_engine_free")
func search_engine_free(_ handle: OpaquePointer?)

@_silgen_name("search_engine_add_item")
func search_engine_add_item(
	_ handle: OpaquePointer?,
	_ id: UnsafePointer<CChar>?,
	_ name: UnsafePointer<CChar>?,
	_ path: UnsafePointer<CChar>?,
	_ itemType: Int32
) -> Bool

@_silgen_name("search_engine_search")
func search_engine_search(
	_ handle: OpaquePointer?,
	_ query: UnsafePointer<CChar>?,
	_ limit: Int,
	_ outCount: UnsafeMutablePointer<Int>?
) -> UnsafeMutablePointer<CSearchResult>?

@_silgen_name("search_results_free")
func search_results_free(_ results: UnsafeMutablePointer<CSearchResult>?, _ count: Int)

@_silgen_name("search_engine_stats")
func search_engine_stats(
	_ handle: OpaquePointer?,
	_ total: UnsafeMutablePointer<Int>?,
	_ apps: UnsafeMutablePointer<Int>?,
	_ files: UnsafeMutablePointer<Int>?,
	_ snippets: UnsafeMutablePointer<Int>?
) -> Bool

@_silgen_name("search_engine_scan_apps")
func search_engine_scan_apps(
	_ handle: OpaquePointer?,
	_ directories: CStringArray,
	_ excludePatterns: CStringArray
) -> Int

struct CIndexedApp {
	var name: UnsafeMutablePointer<CChar>?
	var path: UnsafeMutablePointer<CChar>?
}

@_silgen_name("search_engine_get_apps")
func search_engine_get_apps(
	_ handle: OpaquePointer?,
	_ count: UnsafeMutablePointer<Int>?
) -> UnsafeMutablePointer<CIndexedApp>?

@_silgen_name("indexed_apps_free")
func indexed_apps_free(_ entries: UnsafeMutablePointer<CIndexedApp>?, _ count: Int)

@_silgen_name("snippet_matcher_new")
func snippet_matcher_new() -> OpaquePointer?

@_silgen_name("snippet_matcher_free")
func snippet_matcher_free(_ handle: OpaquePointer?)

@_silgen_name("snippet_matcher_update")
func snippet_matcher_update(_ handle: OpaquePointer?, _ json: UnsafePointer<CChar>?) -> Bool

@_silgen_name("snippet_matcher_find")
func snippet_matcher_find(_ handle: OpaquePointer?, _ text: UnsafePointer<CChar>?)
	-> UnsafeMutablePointer<CSnippetMatch>?

@_silgen_name("snippet_match_free")
func snippet_match_free(_ result: UnsafeMutablePointer<CSnippetMatch>?)

@_silgen_name("app_storage_new")
func app_storage_new(_ path: UnsafePointer<CChar>?) -> OpaquePointer?

@_silgen_name("app_storage_free")
func app_storage_free(_ handle: OpaquePointer?)

@_silgen_name("app_storage_add")
func app_storage_add(
	_ handle: OpaquePointer?, _ name: UnsafePointer<CChar>?, _ path: UnsafePointer<CChar>?
) -> Bool

@_silgen_name("app_storage_get_all")
func app_storage_get_all(_ handle: OpaquePointer?, _ outCount: UnsafeMutablePointer<Int>?)
	-> UnsafeMutablePointer<FFI.CAppEntry>?

@_silgen_name("app_entries_free")
func app_entries_free(_ entries: UnsafeMutablePointer<FFI.CAppEntry>?, _ count: Int)

@_silgen_name("app_storage_len")
func app_storage_len(_ handle: OpaquePointer?) -> Int

@_silgen_name("app_storage_clear")
func app_storage_clear(_ handle: OpaquePointer?) -> Bool

@_silgen_name("settings_storage_new")
func settings_storage_new(_ path: UnsafePointer<CChar>?) -> OpaquePointer?

@_silgen_name("settings_storage_free")
func settings_storage_free(_ handle: OpaquePointer?)

@_silgen_name("settings_storage_get")
func settings_storage_get(_ handle: OpaquePointer?) -> UnsafeMutablePointer<CAppSettings>?

@_silgen_name("settings_storage_save")
// swiftlint:disable:next function_parameter_count
func settings_storage_save(
	_ handle: OpaquePointer?,
	_ theme: UnsafePointer<CChar>?,
	_ customFontName: UnsafePointer<CChar>?,
	_ fontSize: UnsafePointer<CChar>?,
	_ maxResults: Int32,
	_ maxClipboardItems: Int32,
	_ clipboardRetentionDays: Int32,
	_ quickSelectModifier: UnsafePointer<CChar>?,
	_ enableCommands: Bool,
	_ showTrayIcon: Bool,
	_ showDockIcon: Bool,
	_ hideTrafficLights: Bool,
	_ launcherShortcutKey: UnsafePointer<CChar>?,
	_ launcherShortcutMods: UnsafePointer<CChar>?,
	_ clipboardShortcutKey: UnsafePointer<CChar>?,
	_ clipboardShortcutMods: UnsafePointer<CChar>?,
	_ searchFolders: UnsafePointer<CChar>?
) -> Bool

@_silgen_name("settings_free")
func settings_free(_ settings: UnsafeMutablePointer<CAppSettings>?)

@_silgen_name("settings_storage_get_search_folders")
func settings_storage_get_search_folders(_ handle: OpaquePointer?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("settings_storage_get_launcher_shortcut")
func settings_storage_get_launcher_shortcut(_ handle: OpaquePointer?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("settings_storage_get_clipboard_shortcut")
func settings_storage_get_clipboard_shortcut(_ handle: OpaquePointer?) -> UnsafeMutablePointer<CChar>?

extension FFI {
	typealias ActionManagerHandle = OpaquePointer

	struct CActionResult {
		let id: UnsafeMutablePointer<CChar>?
		let title: UnsafeMutablePointer<CChar>?
		let subtitle: UnsafeMutablePointer<CChar>?
		let icon: UnsafeMutablePointer<CChar>?
		let url: UnsafeMutablePointer<CChar>?
		let score: Float
	}

	struct SwiftActionResult {
		let id: String
		let title: String
		let subtitle: String
		let icon: String
		let url: String
		let score: Float
	}

	static func actionManagerNew(path: String) -> ActionManagerHandle? {
		path.withCString { action_manager_new($0) }
	}

	static func actionManagerFree(_ handle: ActionManagerHandle?) {
		guard let handle else { return }
		action_manager_free(handle)
	}

	static func actionManagerSearch(_ handle: ActionManagerHandle?, query: String)
		-> [SwiftActionResult]
	{
		guard let handle else { return [] }

		var count = 0
		let results = query.withCString { queryPtr in
			action_manager_search(handle, queryPtr, &count)
		}

		guard let results, count > 0 else { return [] }
		defer { action_results_free(results, count) }

		var output: [SwiftActionResult] = []
		for i in 0 ..< count {
			let result = results[i]
			guard let id = FFIHelpers.safeString(from: result.id),
			      let title = FFIHelpers.safeString(from: result.title),
			      let subtitle = FFIHelpers.safeString(from: result.subtitle),
			      let icon = FFIHelpers.safeString(from: result.icon),
			      let url = FFIHelpers.safeString(from: result.url)
			else { continue }

			output.append(
				SwiftActionResult(
					id: id,
					title: title,
					subtitle: subtitle,
					icon: icon,
					url: url,
					score: result.score
				))
		}
		return output
	}

	static func actionManagerAddQuickLink(
		_ handle: ActionManagerHandle?,
		id: String,
		name: String,
		keyword: String,
		url: String,
		icon: String
	) -> Bool {
		guard let handle else { return false }
		return id.withCString { idPtr in
			name.withCString { namePtr in
				keyword.withCString { keywordPtr in
					url.withCString { urlPtr in
						icon.withCString { iconPtr in
							action_manager_add_quick_link(
								handle, idPtr, namePtr, keywordPtr, urlPtr, iconPtr
							)
						}
					}
				}
			}
		}
	}

	static func actionManagerAddPattern(
		_ handle: ActionManagerHandle?,
		id: String,
		name: String,
		pattern: String,
		url: String,
		icon: String
	) -> Bool {
		guard let handle else { return false }
		return id.withCString { idPtr in
			name.withCString { namePtr in
				pattern.withCString { patternPtr in
					url.withCString { urlPtr in
						icon.withCString { iconPtr in
							action_manager_add_pattern(
								handle, idPtr, namePtr, patternPtr, urlPtr, iconPtr
							)
						}
					}
				}
			}
		}
	}

	static func actionManagerAddJSON(_ handle: ActionManagerHandle?, json: String) -> Bool {
		guard let handle else { return false }
		return json.withCString { action_manager_add_json(handle, $0) }
	}

	static func actionManagerUpdateJSON(_ handle: ActionManagerHandle?, json: String) -> Bool {
		guard let handle else { return false }
		return json.withCString { action_manager_update_json(handle, $0) }
	}

	static func actionManagerRemove(_ handle: ActionManagerHandle?, id: String) -> Bool {
		guard let handle else { return false }
		return id.withCString { action_manager_remove(handle, $0) }
	}

	static func actionManagerToggle(_ handle: ActionManagerHandle?, id: String) -> Bool {
		guard let handle else { return false }
		return id.withCString { action_manager_toggle(handle, $0) }
	}

	static func actionManagerGetAllJSON(_ handle: ActionManagerHandle?) -> String? {
		guard let handle else { return nil }
		guard let json = action_manager_get_all_json(handle) else { return nil }
		defer { string_free(json) }
		return String(cString: json)
	}

	static func actionManagerImportDefaults(_ handle: ActionManagerHandle?) -> Bool {
		guard let handle else { return false }
		return action_manager_import_defaults(handle)
	}
}

@_silgen_name("action_manager_new")
func action_manager_new(_ path: UnsafePointer<CChar>?) -> OpaquePointer?

@_silgen_name("action_manager_free")
func action_manager_free(_ handle: OpaquePointer?)

@_silgen_name("action_manager_search")
func action_manager_search(
	_ handle: OpaquePointer?,
	_ query: UnsafePointer<CChar>?,
	_ outCount: UnsafeMutablePointer<Int>?
) -> UnsafeMutablePointer<FFI.CActionResult>?

@_silgen_name("action_results_free")
func action_results_free(_ results: UnsafeMutablePointer<FFI.CActionResult>?, _ count: Int)

@_silgen_name("action_manager_add_json")
func action_manager_add_json(_ handle: OpaquePointer?, _ json: UnsafePointer<CChar>?) -> Bool

@_silgen_name("action_manager_add_quick_link")
func action_manager_add_quick_link(
	_ handle: OpaquePointer?,
	_ id: UnsafePointer<CChar>?,
	_ name: UnsafePointer<CChar>?,
	_ keyword: UnsafePointer<CChar>?,
	_ url: UnsafePointer<CChar>?,
	_ icon: UnsafePointer<CChar>?
) -> Bool

@_silgen_name("action_manager_add_pattern")
func action_manager_add_pattern(
	_ handle: OpaquePointer?,
	_ id: UnsafePointer<CChar>?,
	_ name: UnsafePointer<CChar>?,
	_ pattern: UnsafePointer<CChar>?,
	_ url: UnsafePointer<CChar>?,
	_ icon: UnsafePointer<CChar>?
) -> Bool

@_silgen_name("action_manager_update_json")
func action_manager_update_json(_ handle: OpaquePointer?, _ json: UnsafePointer<CChar>?) -> Bool

@_silgen_name("action_manager_remove")
func action_manager_remove(_ handle: OpaquePointer?, _ id: UnsafePointer<CChar>?) -> Bool

@_silgen_name("action_manager_toggle")
func action_manager_toggle(_ handle: OpaquePointer?, _ id: UnsafePointer<CChar>?) -> Bool

@_silgen_name("action_manager_get_all_json")
func action_manager_get_all_json(_ handle: OpaquePointer?) -> UnsafeMutablePointer<CChar>?

@_silgen_name("action_manager_import_defaults")
func action_manager_import_defaults(_ handle: OpaquePointer?) -> Bool

@_silgen_name("string_free")
func string_free(_ s: UnsafeMutablePointer<CChar>?)
