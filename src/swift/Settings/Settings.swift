import AppKit
import Carbon
import Foundation
import SwiftUI

struct KeyboardShortcut: Codable, Equatable {
	let keyCode: UInt32
	let modifiers: UInt32

	private static let modifierMap: [(UInt32, String)] = [
		(UInt32(cmdKey), "⌘"), (UInt32(optionKey), "⌥"),
		(UInt32(shiftKey), "⇧"), (UInt32(controlKey), "⌃")
	]

	var displayString: String {
		let parts =
			Self.modifierMap.compactMap { modifiers & $0.0 != 0 ? $0.1 : nil } + [
				keyCodeToString(keyCode)
			]
		return parts.joined(separator: " ")
	}

	private func keyCodeToString(_ code: UInt32) -> String {
		KeyCodeMapping.keyCodeToString[Int(code)] ?? "?"
	}

	static var defaultLauncher: KeyboardShortcut {
		KeyboardShortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
	}

	static var defaultClipboard: KeyboardShortcut {
		KeyboardShortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey | shiftKey))
	}

	// Action shortcuts
	static var defaultPinApp: KeyboardShortcut {
		KeyboardShortcut(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(cmdKey))
	}

	static var defaultRevealApp: KeyboardShortcut {
		KeyboardShortcut(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(cmdKey))
	}

	static var defaultCopyPath: KeyboardShortcut {
		KeyboardShortcut(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey | optionKey))
	}

	static var defaultQuitApp: KeyboardShortcut {
		KeyboardShortcut(keyCode: UInt32(kVK_ANSI_Q), modifiers: UInt32(cmdKey))
	}

	static var defaultHideApp: KeyboardShortcut {
		KeyboardShortcut(keyCode: UInt32(kVK_ANSI_H), modifiers: UInt32(cmdKey))
	}

	static var defaultSaveClipboard: KeyboardShortcut {
		KeyboardShortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(cmdKey))
	}

	static var defaultDeleteClipboard: KeyboardShortcut {
		KeyboardShortcut(keyCode: UInt32(kVK_Delete), modifiers: UInt32(cmdKey))
	}

	static var defaultForceQuit: KeyboardShortcut {
		KeyboardShortcut(keyCode: UInt32(kVK_ANSI_Q), modifiers: UInt32(cmdKey | optionKey))
	}

	static var defaultGetInfo: KeyboardShortcut {
		KeyboardShortcut(keyCode: UInt32(kVK_ANSI_I), modifiers: UInt32(cmdKey))
	}
}

struct RecentApp: Codable, Equatable {
	let name: String
	let path: String
	let timestamp: Double
}

struct WebSearchEngine: Codable, Identifiable, Hashable {
	let id: String
	let name: String
	let urlTemplate: String
	let iconName: String
	var keyword: String?

	static let defaults: [WebSearchEngine] = [
		WebSearchEngine(
			id: "google", name: "Google", urlTemplate: "https://www.google.com/search?q={query}",
			iconName: "web:google", keyword: "g"
		),
		WebSearchEngine(
			id: "duckduckgo", name: "DuckDuckGo", urlTemplate: "https://duckduckgo.com/?q={query}",
			iconName: "web:duckduckgo", keyword: "ddg"
		),
		WebSearchEngine(
			id: "startpage", name: "Startpage",
			urlTemplate: "https://www.startpage.com/do/search?q={query}", iconName: "web:startpage",
			keyword: "sp"
		),
		WebSearchEngine(
			id: "ecosia", name: "Ecosia", urlTemplate: "https://www.ecosia.org/search?q={query}",
			iconName: "web:ecosia", keyword: "eco"
		),
		WebSearchEngine(
			id: "brave", name: "Brave Search",
			urlTemplate: "https://search.brave.com/search?q={query}", iconName: "web:brave",
			keyword: "brave"
		),
		WebSearchEngine(
			id: "kagi", name: "Kagi", urlTemplate: "https://kagi.com/search?q={query}",
			iconName: "web:kagi", keyword: "kagi"
		)
	]
}

enum FallbackSearchBehavior: String, Codable, CaseIterable {
	case onlyWhenEmpty = "only_when_empty"
	case appendToResults = "append_to_results"

	var displayName: String {
		switch self {
		case .onlyWhenEmpty: "Only when no results"
		case .appendToResults: "Append to results"
		}
	}
}

class AppSettings: ObservableObject {
	static let shared = AppSettings()

	@Published var theme: Theme = .dark
	@Published var customFontName: String = ""
	@Published var fontSize: FontSize = .medium
	@Published var windowShadowRadius: Double = 12.0
	@Published var windowShadowOpacity: Double = 0.3
	@Published var maxResults: Int = 7
	@Published var maxClipboardItems: Int = 30
	@Published var clipboardRetentionDays: Int = 7
	@Published var launcherShortcut: KeyboardShortcut = .defaultLauncher
	@Published var clipboardShortcut: KeyboardShortcut = .defaultClipboard
	@Published var quickSelectModifier: QuickSelectModifier = .command

	// Action shortcuts
	@Published var pinAppShortcut: KeyboardShortcut = .defaultPinApp
	@Published var revealAppShortcut: KeyboardShortcut = .defaultRevealApp
	@Published var copyPathShortcut: KeyboardShortcut = .defaultCopyPath
	@Published var quitAppShortcut: KeyboardShortcut = .defaultQuitApp
	@Published var hideAppShortcut: KeyboardShortcut = .defaultHideApp
	@Published var saveClipboardShortcut: KeyboardShortcut = .defaultSaveClipboard
	@Published var deleteClipboardShortcut: KeyboardShortcut = .defaultDeleteClipboard
	@Published var forceQuitShortcut: KeyboardShortcut = .defaultForceQuit
	@Published var getInfoShortcut: KeyboardShortcut = .defaultGetInfo
	@Published var enableCommands: Bool = true
	@Published var showTrayIcon: Bool = true
	@Published var showDockIcon: Bool = false
	@Published var hideTrafficLights: Bool = false
	@Published var showFooterHints: Bool = true
	@Published var compactMode: Bool = false
	@Published var showRecentAppsOnLanding: Bool = true
	@Published var imageSavePath: String = ""
	@Published var showQuickSelect: Bool = true
	@Published var recentApps: [RecentApp] = []
	@Published var recentAppsGeneration: Int = 0
	@Published var pinnedApps: [RecentApp] = []
	@Published var searchFolders: [String] = [
		"/Applications",
		"/System/Applications",
		"/System/Applications/Utilities"
	]
	@Published var enableFileSearch: Bool = true
	@Published var fileSearchDirectories: [String] = [
		NSHomeDirectory() + "/Documents",
		NSHomeDirectory() + "/Desktop"
	]
	@Published var fileSearchExtensions: [String] = [
		"txt", "md", "pdf", "doc", "docx"
	]
	@Published var launcherAllowedExtensions: [String] = [
		"app", "prefPane", "workflow"
	]
	@Published var enableFallbackSearch: Bool = true
	@Published var fallbackSearchBehavior: FallbackSearchBehavior = .onlyWhenEmpty
	@Published var fallbackSearchEngines: [String] = ["google", "duckduckgo"]
	@Published var fallbackSearchMinQueryLength: Int = 2
	@Published var fallbackSearchMaxEngines: Int = 2
	@Published var customFallbackEngines: [WebSearchEngine] = []
	@Published var engineKeywords: [String: String] = [:]
	@Published var disabledDefaultEngines: Set<String> = []

	private var settingsStorage: FFI.SettingsStorageHandle?
	private let userDefaults = UserDefaults.standard
	private let saveDebouncer = Debouncer(delay: 0.5)
	private let recentAppsKey = "app_recentApps"
	private let pinnedAppsKey = "app_pinnedApps"
	private let customEnginesKey = "app_customFallbackEngines"
	private let engineKeywordsKey = "app_engineKeywords"
	private let disabledDefaultEnginesKey = "app_disabledDefaultEngines"
	private let showFooterHintsKey = "app_showFooterHints"
	private let compactModeKey = "app_compactMode"
	private let showRecentAppsOnLandingKey = "app_showRecentAppsOnLanding"
	private let imageSavePathKey = "app_imageSavePath"
	private let showQuickSelectKey = "app_showQuickSelect"
	private let pinAppShortcutKey = "app_pinAppShortcut"
	private let revealAppShortcutKey = "app_revealAppShortcut"
	private let copyPathShortcutKey = "app_copyPathShortcut"
	private let quitAppShortcutKey = "app_quitAppShortcut"
	private let hideAppShortcutKey = "app_hideAppShortcut"
	private let saveClipboardShortcutKey = "app_saveClipboardShortcut"

	deinit {
		FFI.settingsStorageFree(settingsStorage)
	}

	var uiFont: NSFont {
		let size = fontSize.size
		return customFontName
			.isEmpty
			? .systemFont(ofSize: size)
			: NSFont(name: customFontName, size: size) ?? .systemFont(ofSize: size)
	}

	private func font(size: CGFloat, weight: Font.Weight? = nil) -> Font {
		guard customFontName.isEmpty else { return .custom(customFontName, size: size) }
		if let weight {
			return .system(size: size).weight(weight)
		}
		return .system(size: size)
	}

	var swiftUIFont: Font { font(size: fontSize.searchFieldSize) }
	var resultNameFont: Font { font(size: fontSize.resultNameSize, weight: .medium) }
	var resultCategoryFont: Font { font(size: fontSize.resultCategorySize) }

	init() {
		let appSupport = FileManager.default.urls(
			for: .applicationSupportDirectory, in: .userDomainMask
		).first!
		let invokeDir = appSupport.appendingPathComponent("Summon", isDirectory: true)
		try? FileManager.default.createDirectory(at: invokeDir, withIntermediateDirectories: true)
		let storagePath = invokeDir.appendingPathComponent("settings.rkyv").path
		settingsStorage = FFI.settingsStorageNew(path: storagePath)

		load()
	}

	func load() {
		if let swiftSettings = FFI.settingsStorageGet(settingsStorage) {
			theme = Theme(rawValue: swiftSettings.theme) ?? .dark
			customFontName = swiftSettings.customFontName
			fontSize = FontSize(rawValue: swiftSettings.fontSize) ?? .medium
			maxResults = swiftSettings.maxResults
			maxClipboardItems = swiftSettings.maxClipboardItems
			clipboardRetentionDays = swiftSettings.clipboardRetentionDays
			quickSelectModifier =
				QuickSelectModifier(rawValue: swiftSettings.quickSelectModifier) ?? .command
			enableCommands = swiftSettings.enableCommands
			showTrayIcon = swiftSettings.showTrayIcon
			showDockIcon = swiftSettings.showDockIcon
			hideTrafficLights = swiftSettings.hideTrafficLights
			searchFolders =
				swiftSettings.searchFolders.isEmpty
					? [
						"/Applications",
						"/System/Applications",
						"/System/Applications/Utilities"
					] : swiftSettings.searchFolders

			launcherShortcut =
				ShortcutManager.decode(
					key: swiftSettings.launcherShortcutKey,
					mods: swiftSettings.launcherShortcutMods
				) ?? .defaultLauncher

			clipboardShortcut =
				ShortcutManager.decode(
					key: swiftSettings.clipboardShortcutKey,
					mods: swiftSettings.clipboardShortcutMods
				) ?? .defaultClipboard
		}

		recentApps = userDefaults.decodable([RecentApp].self, forKey: recentAppsKey) ?? []
		pinnedApps = userDefaults.decodable([RecentApp].self, forKey: pinnedAppsKey) ?? []
		customFallbackEngines = userDefaults.decodable([WebSearchEngine].self, forKey: customEnginesKey) ?? []

		engineKeywords = userDefaults.decodable([String: String].self, forKey: engineKeywordsKey) ?? [:]
		disabledDefaultEngines = userDefaults.decodable(Set<String>.self, forKey: disabledDefaultEnginesKey) ?? []

		if userDefaults.object(forKey: showFooterHintsKey) != nil {
			showFooterHints = userDefaults.bool(forKey: showFooterHintsKey)
		}

		if userDefaults.object(forKey: compactModeKey) != nil {
			compactMode = userDefaults.bool(forKey: compactModeKey)
		}

		if userDefaults.object(forKey: showRecentAppsOnLandingKey) != nil {
			showRecentAppsOnLanding = userDefaults.bool(forKey: showRecentAppsOnLandingKey)
		}

		if let savedPath = userDefaults.string(forKey: imageSavePathKey), !savedPath.isEmpty {
			imageSavePath = savedPath
		}

		if userDefaults.object(forKey: showQuickSelectKey) != nil {
			showQuickSelect = userDefaults.bool(forKey: showQuickSelectKey)
		}

		if let shortcut = userDefaults.decodable(KeyboardShortcut.self, forKey: pinAppShortcutKey) {
			pinAppShortcut = shortcut
		}
		if let shortcut = userDefaults.decodable(KeyboardShortcut.self, forKey: revealAppShortcutKey) {
			revealAppShortcut = shortcut
		}
		if let shortcut = userDefaults.decodable(KeyboardShortcut.self, forKey: copyPathShortcutKey) {
			copyPathShortcut = shortcut
		}
		if let shortcut = userDefaults.decodable(KeyboardShortcut.self, forKey: quitAppShortcutKey) {
			quitAppShortcut = shortcut
		}
		if let shortcut = userDefaults.decodable(KeyboardShortcut.self, forKey: hideAppShortcutKey) {
			hideAppShortcut = shortcut
		}
		if let shortcut = userDefaults.decodable(KeyboardShortcut.self, forKey: saveClipboardShortcutKey) {
			saveClipboardShortcut = shortcut
		}
	}

	func addRecentApp(name: String, path: String) {
		if pinnedApps.contains(where: { $0.path == path }) {
			return
		}

		let now = Date().timeIntervalSince1970
		var updated = recentApps.filter { $0.path != path }
		updated.insert(RecentApp(name: name, path: path, timestamp: now), at: 0)
		recentApps = Array(updated.prefix(maxResults))

		userDefaults.setEncodable(recentApps, forKey: recentAppsKey)
	}

	func cleanInvalidApps() {
		let validRecent = recentApps.filter { app in
			let exists = app.path.fileExists
			if !exists {
				print("Removing invalid recent app: \(app.name) at \(app.path)")
			}
			return exists
		}

		if validRecent.count != recentApps.count {
			recentApps = validRecent
			userDefaults.setEncodable(recentApps, forKey: recentAppsKey)
		}

		let validPinned = pinnedApps.filter { item in
			if item.path.hasPrefix("cmd_") {
				return true
			}
			let exists = item.path.fileExists
			if !exists {
				print("Removing invalid pinned app: \(item.name) at \(item.path)")
			}
			return exists
		}

		if validPinned.count != pinnedApps.count {
			pinnedApps = validPinned
			userDefaults.setEncodable(pinnedApps, forKey: pinnedAppsKey)
		}
	}

	func togglePinApp(name: String, path: String) {
		if let index = pinnedApps.firstIndex(where: { $0.path == path }) {
			pinnedApps.remove(at: index)
		} else {
			let now = Date().timeIntervalSince1970
			pinnedApps.append(RecentApp(name: name, path: path, timestamp: now))
			recentApps.removeAll { $0.path == path }
		}

		userDefaults.setEncodable(pinnedApps, forKey: pinnedAppsKey)
		userDefaults.setEncodable(recentApps, forKey: recentAppsKey)
	}

	func isAppPinned(path: String) -> Bool {
		pinnedApps.contains(where: { $0.path == path })
	}

	func scheduleSave() {
		guard Thread.isMainThread else {
			DispatchQueue.main.async { [weak self] in
				self?.scheduleSave()
			}
			return
		}

		saveDebouncer.debounce { [weak self] in
			self?.saveNow()
		}
	}

	private func saveNow() {
		let (launcherKey, launcherMods) = ShortcutManager.encode(launcherShortcut)
		let (clipboardKey, clipboardMods) = ShortcutManager.encode(clipboardShortcut)

		_ = FFI.settingsStorageSave(
			settingsStorage,
			theme: theme.rawValue,
			customFontName: customFontName,
			fontSize: fontSize.rawValue,
			maxResults: maxResults,
			maxClipboardItems: maxClipboardItems,
			clipboardRetentionDays: clipboardRetentionDays,
			quickSelectModifier: quickSelectModifier.rawValue,
			enableCommands: enableCommands,
			showTrayIcon: showTrayIcon,
			showDockIcon: showDockIcon,
			hideTrafficLights: hideTrafficLights,
			launcherShortcutKey: launcherKey,
			launcherShortcutMods: launcherMods,
			clipboardShortcutKey: clipboardKey,
			clipboardShortcutMods: clipboardMods,
			searchFolders: searchFolders
		)

		userDefaults.setEncodable(customFallbackEngines, forKey: customEnginesKey)
		userDefaults.setEncodable(engineKeywords, forKey: engineKeywordsKey)
		userDefaults.setEncodable(disabledDefaultEngines, forKey: disabledDefaultEnginesKey)

		userDefaults.set(showFooterHints, forKey: showFooterHintsKey)
		userDefaults.set(compactMode, forKey: compactModeKey)
		userDefaults.set(showRecentAppsOnLanding, forKey: showRecentAppsOnLandingKey)
		userDefaults.set(imageSavePath, forKey: imageSavePathKey)
		userDefaults.set(showQuickSelect, forKey: showQuickSelectKey)

		userDefaults.setEncodable(pinAppShortcut, forKey: pinAppShortcutKey)
		userDefaults.setEncodable(revealAppShortcut, forKey: revealAppShortcutKey)
		userDefaults.setEncodable(copyPathShortcut, forKey: copyPathShortcutKey)
		userDefaults.setEncodable(quitAppShortcut, forKey: quitAppShortcutKey)
		userDefaults.setEncodable(hideAppShortcut, forKey: hideAppShortcutKey)
		userDefaults.setEncodable(saveClipboardShortcut, forKey: saveClipboardShortcutKey)
	}

	func save() {
		saveNow()
	}

	func saveAndReindex() {
		saveNow()
		NotificationCenter.default.post(name: .settingsChanged, object: nil)
	}

	var allFallbackEngines: [WebSearchEngine] {
		let enabledDefaults = WebSearchEngine.defaults.filter {
			!disabledDefaultEngines.contains($0.id)
		}
		return enabledDefaults + customFallbackEngines
	}

	func addFallbackEngine(name: String, urlTemplate: String, iconName: String) {
		let id = UUID().uuidString
		let engine = WebSearchEngine(
			id: id, name: name, urlTemplate: urlTemplate, iconName: iconName
		)
		customFallbackEngines.append(engine)
		fallbackSearchEngines.append(id)
		scheduleSave()
	}

	func updateFallbackEngine(id: String, name: String, urlTemplate: String, iconName: String) {
		if let index = customFallbackEngines.firstIndex(where: { $0.id == id }) {
			let oldIconName = customFallbackEngines[index].iconName.replacingOccurrences(
				of: "web:", with: ""
			)
			if oldIconName != iconName.replacingOccurrences(of: "web:", with: ""),
			   oldIconName != "globe",
			   !oldIconName.isEmpty
			{
				WebIconDownloader.deleteIcon(forName: oldIconName)
			}

			customFallbackEngines[index] = WebSearchEngine(
				id: id,
				name: name,
				urlTemplate: urlTemplate,
				iconName: iconName
			)
			scheduleSave()
		}
	}

	func removeFallbackEngine(id: String) {
		let engine = customFallbackEngines.first { $0.id == id }
		let iconName = engine?.iconName.replacingOccurrences(of: "web:", with: "")

		if WebSearchEngine.defaults.contains(where: { $0.id == id }) {
			disabledDefaultEngines.insert(id)
		} else {
			customFallbackEngines.removeAll { $0.id == id }
		}
		fallbackSearchEngines.removeAll { $0 == id }

		if let iconName, iconName != "globe", !iconName.isEmpty {
			WebIconDownloader.deleteIcon(forName: iconName)
		}

		scheduleSave()
	}

	func updateEngineKeyword(id: String, keyword: String) {
		if keyword.isEmpty {
			engineKeywords.removeValue(forKey: id)
		} else {
			engineKeywords[id] = keyword
		}
		scheduleSave()
	}

	func getEngineKeyword(id: String) -> String {
		if let override = engineKeywords[id] {
			return override
		}
		return allFallbackEngines.first { $0.id == id }?.keyword ?? ""
	}

	func fallbackEngineById(_ id: String) -> WebSearchEngine? {
		allFallbackEngines.first { $0.id == id }
	}
}

enum Theme: String, CaseIterable {
	case dark, light
	case tokyoNight = "tokyo-night"
	case oneDark = "one-dark"
	case gruvbox, nord, dracula, catppuccin

	private static let themeData:
		[Theme: (
			name: String,
			bg: (Double, Double, Double),
			searchBar: (Double, Double, Double),
			preview: (Double, Double, Double),
			metadata: (Double, Double, Double),
			text: (Double, Double, Double),
			secondaryText: (Double, Double, Double),
			accent: (Double, Double, Double)
		)] = [
			.dark: (
				"Dark",
				(0.11, 0.11, 0.11),
				(0.15, 0.15, 0.15),
				(0.14, 0.14, 0.14),
				(0.12, 0.12, 0.12),
				(0.90, 0.90, 0.90),
				(0.60, 0.60, 0.60),
				(0.35, 0.60, 1.00)
			),
			.light: (
				"Light",
				(0.95, 0.95, 0.95),
				(0.88, 0.88, 0.88),
				(0.90, 0.90, 0.90),
				(0.85, 0.85, 0.85),
				(0.10, 0.10, 0.10),
				(0.40, 0.40, 0.40),
				(0.00, 0.48, 1.00)
			),
			.tokyoNight: (
				"Tokyo Night",
				(0.09, 0.10, 0.14),
				(0.12, 0.13, 0.18),
				(0.11, 0.12, 0.16),
				(0.10, 0.11, 0.15),
				(0.90, 0.90, 0.90),
				(0.60, 0.60, 0.60),
				(0.45, 0.68, 0.98)
			),
			.oneDark: (
				"One Dark",
				(0.16, 0.17, 0.21),
				(0.19, 0.20, 0.24),
				(0.18, 0.19, 0.23),
				(0.17, 0.18, 0.22),
				(0.90, 0.90, 0.90),
				(0.60, 0.60, 0.60),
				(0.38, 0.68, 0.98)
			),
			.gruvbox: (
				"Gruvbox",
				(0.16, 0.15, 0.13),
				(0.20, 0.19, 0.17),
				(0.19, 0.18, 0.16),
				(0.18, 0.17, 0.15),
				(0.90, 0.90, 0.90),
				(0.60, 0.60, 0.60),
				(0.98, 0.70, 0.38)
			),
			.nord: (
				"Nord",
				(0.18, 0.20, 0.25),
				(0.22, 0.24, 0.29),
				(0.21, 0.23, 0.28),
				(0.20, 0.22, 0.27),
				(0.90, 0.90, 0.90),
				(0.60, 0.60, 0.60),
				(0.53, 0.75, 0.82)
			),
			.dracula: (
				"Dracula",
				(0.16, 0.17, 0.21),
				(0.20, 0.21, 0.26),
				(0.19, 0.20, 0.25),
				(0.18, 0.19, 0.24),
				(0.90, 0.90, 0.90),
				(0.60, 0.60, 0.60),
				(1.00, 0.47, 0.78)
			),
			.catppuccin: (
				"Catppuccin",
				(0.11, 0.11, 0.16),
				(0.14, 0.14, 0.19),
				(0.13, 0.13, 0.18),
				(0.12, 0.12, 0.17),
				(0.90, 0.90, 0.90),
				(0.60, 0.60, 0.60),
				(0.75, 0.71, 0.99)
			)
		]

	var name: String { Self.themeData[self]!.name }
	var backgroundColor: (Double, Double, Double) { Self.themeData[self]!.bg }
	var searchBarColor: (Double, Double, Double) { Self.themeData[self]!.searchBar }
	var previewColor: (Double, Double, Double) { Self.themeData[self]!.preview }
	var metadataColor: (Double, Double, Double) { Self.themeData[self]!.metadata }
	var textColor: (Double, Double, Double) { Self.themeData[self]!.text }
	var secondaryTextColor: (Double, Double, Double) { Self.themeData[self]!.secondaryText }
	var accentColor: (Double, Double, Double) { Self.themeData[self]!.accent }
}

enum FontSize: String, CaseIterable {
	case small, medium, large

	private static let sizeData:
		[FontSize: (
			name: String,
			searchField: CGFloat,
			resultName: CGFloat,
			resultCategory: CGFloat,
			previewText: CGFloat,
			size: CGFloat
		)] = [
			.small: ("Small", 18, 12, 10, 11, 13),
			.medium: ("Medium", 20, 14, 12, 13, 15),
			.large: ("Large", 22, 16, 14, 15, 17)
		]

	var name: String { Self.sizeData[self]!.name }
	var searchFieldSize: CGFloat { Self.sizeData[self]!.searchField }
	var resultNameSize: CGFloat { Self.sizeData[self]!.resultName }
	var resultCategorySize: CGFloat { Self.sizeData[self]!.resultCategory }
	var previewTextSize: CGFloat { Self.sizeData[self]!.previewText }
	var size: CGFloat { Self.sizeData[self]!.size }
}

enum FontFamily: String, Codable, Equatable {
	case system, menlo, monaco
	case sfMono = "sf-mono"
	case sfPro = "sf-pro"

	static var allCases: [FontFamily] { [.system, .sfMono, .sfPro, .menlo, .monaco] }

	private static let fontData: [FontFamily: (name: String, fontName: String?)] = [
		.system: ("System", nil),
		.sfMono: ("SF Mono", "SFMono-Regular"),
		.sfPro: ("SF Pro", "SFProText-Regular"),
		.menlo: ("Menlo", "Menlo-Regular"),
		.monaco: ("Monaco", "Monaco")
	]

	var name: String { Self.fontData[self]!.name }
	var fontName: String? { Self.fontData[self]!.fontName }
}

enum QuickSelectModifier: String, CaseIterable {
	case option, command, control

	private static let modData:
		[QuickSelectModifier: (name: String, symbol: String, flag: NSEvent.ModifierFlags)] = [
			.option: ("⌥ Option", "⌥", .option),
			.command: ("⌘ Command", "⌘", .command),
			.control: ("⌃ Control", "⌃", .control)
		]

	var name: String { Self.modData[self]!.name }
	var displaySymbol: String { Self.modData[self]!.symbol }
	var eventFlag: NSEvent.ModifierFlags { Self.modData[self]!.flag }
}
