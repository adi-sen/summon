import Carbon
import SwiftUI

extension Notification.Name {
	static let showClipboard = Notification.Name("showClipboard")
	static let showLauncher = Notification.Name("showLauncher")
	static let showSettings = Notification.Name("showSettings")
	static let shortcutsChanged = Notification.Name("shortcutsChanged")
	static let clearIconCache = Notification.Name("clearIconCache")
	static let windowHidden = Notification.Name("windowHidden")
	static let settingsChanged = Notification.Name("settingsChanged")
	static let trayIconSettingChanged = Notification.Name("trayIconSettingChanged")
	static let dockIconSettingChanged = Notification.Name("dockIconSettingChanged")
	static let trafficLightsSettingChanged = Notification.Name("trafficLightsSettingChanged")
	static let closeAllDropdowns = Notification.Name("closeAllDropdowns")
	static let saveClipboardAsSnippet = Notification.Name("saveClipboardAsSnippet")
}

@main
struct SummonApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

	var body: some Scene {
		Settings {
			EmptyView()
				.frame(width: 0, height: 0)
				.hidden()
		}
		.commands {
			CommandGroup(replacing: .appSettings) {}
		}
	}
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
	weak static var shared: AppDelegate?

	var window: NSWindow?
	var settingsWindow: NSWindow?
	var searchEngine: SearchEngine?
	var hotKeyMonitor: HotKeyMonitor?
	var statusBarManager: StatusBarManager?
	var clipboardManager: ClipboardManager?
	var snippetExpander: SnippetExpander?
	private var appStorage: FFI.AppStorageHandle?
	private let appStorageLock = NSLock()
	private var cacheRebuildScheduled = false
	private var cacheRebuildWorkItem: DispatchWorkItem?
	private var invalidAppPaths = Set<String>()
	private let invalidAppPathsLock = NSLock()

	deinit {
		appStorageLock.lock()
		defer { appStorageLock.unlock() }
		FFI.appStorageFree(appStorage)
	}

	func applicationDidFinishLaunching(_: Notification) {
		AppDelegate.shared = self
		updateActivationPolicy()

		searchEngine = SearchEngine()

		clipboardManager = ClipboardManager()
		clipboardManager?.start()

		snippetExpander = SnippetExpander.shared
		snippetExpander?.start()

		setupFloatingWindow()
		setupHotKey()
		setupStatusBar()

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleShortcutsChanged),
			name: .shortcutsChanged,
			object: nil
		)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleShowSettings),
			name: .showSettings,
			object: nil
		)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleShowSettings),
			name: .openSettings,
			object: nil
		)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleSettingsChanged),
			name: .settingsChanged,
			object: nil
		)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleTrayIconSettingChanged),
			name: .trayIconSettingChanged,
			object: nil
		)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleDockIconSettingChanged),
			name: .dockIconSettingChanged,
			object: nil
		)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleTrafficLightsSettingChanged),
			name: .trafficLightsSettingChanged,
			object: nil
		)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleRefreshAppIndex),
			name: .refreshAppIndex,
			object: nil
		)

		indexApplications()
		indexCommands()

		Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
			self?.performMemoryCleanup()
		}
	}

	private func performMemoryCleanup() {
		autoreleasepool {
			clipboardManager?.cleanupOldEntries()

			if let window, !window.isVisible {
				NotificationCenter.default.post(name: .clearIconCache, object: nil)
			}

			malloc_zone_pressure_relief(nil, 0)
		}
	}

	private func setupStatusBar() {
		statusBarManager = StatusBarManager()
		statusBarManager?.onToggle = { [weak self] in
			self?.toggleWindow()
		}
		statusBarManager?.onSettings = { [weak self] in
			self?.openSettings()
		}
		statusBarManager?.onQuit = {
			NSApp.terminate(nil)
		}
		if AppSettings.shared.showTrayIcon {
			statusBarManager?.setup()
		}
	}

	private func setupFloatingWindow() {
		var contentView = ContentView(
			searchEngine: searchEngine!,
			clipboardManager: clipboardManager!
		)
		contentView.onOpenSettings = { [weak self] in
			self?.showSettingsWindow()
		}

		window = FloatingPanel(
			contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
			backing: .buffered,
			defer: false
		)
		window?.contentView = NSHostingView(rootView: contentView)
		window?.center()
	}

	private func setupHotKey() {
		if hotKeyMonitor == nil {
			hotKeyMonitor = HotKeyMonitor()
			hotKeyMonitor?.setupEventHandler()
		}

		registerHotKeys()
	}

	private func registerHotKeys() {
		let settings = AppSettings.shared

		hotKeyMonitor?.unregisterAllHotKeys()

		hotKeyMonitor?.registerHotKey(
			keyCode: settings.launcherShortcut.keyCode,
			modifiers: settings.launcherShortcut.modifiers
		) { [weak self] in
			self?.toggleWindow()
		}

		hotKeyMonitor?.registerHotKey(
			keyCode: settings.clipboardShortcut.keyCode,
			modifiers: settings.clipboardShortcut.modifiers
		) { [weak self] in
			self?.openClipboardManager()
		}
	}

	@objc private func handleShortcutsChanged() {
		registerHotKeys()
	}

	@objc private func handleShowSettings() {
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
			self?.showSettingsWindow()
		}
	}

	@objc private func handleSettingsChanged() {
		print("Settings changed - clearing app cache...")

		DispatchQueue.main.async { [weak self] in
			guard let self else { return }
			self.clearAppCache()
		}
	}

	private func clearAppCache() {
		guard Thread.isMainThread else {
			DispatchQueue.main.sync { [weak self] in
				self?.clearAppCache()
			}
			return
		}

		appStorageLock.lock()
		defer { appStorageLock.unlock() }

		if let appStorage {
			_ = FFI.appStorageClear(appStorage)
			FFI.appStorageFree(appStorage)
			self.appStorage = nil
		}

		let storagePath = getAppStoragePath()
		try? FileManager.default.removeItem(atPath: storagePath)
		print("Cleared app cache at: \(storagePath)")

		searchEngine?.clear()

		invalidAppPathsLock.lock()
		invalidAppPaths.removeAll()
		invalidAppPathsLock.unlock()

		cacheRebuildScheduled = false
	}

	func isKnownInvalidApp(path: String) -> Bool {
		invalidAppPathsLock.lock()
		defer { invalidAppPathsLock.unlock() }
		return invalidAppPaths.contains(path)
	}

	func markAppAsValid(path: String) {
		invalidAppPathsLock.lock()
		let wasRemoved = invalidAppPaths.remove(path) != nil
		invalidAppPathsLock.unlock()

		if wasRemoved {
			print("App is now valid again: \(path)")
		}
	}

	func markAppAsInvalid(path: String) {
		invalidAppPathsLock.lock()
		let wasNew = invalidAppPaths.insert(path).inserted
		invalidAppPathsLock.unlock()

		if wasNew {
			print("Marking app as invalid: \(path)")
			scheduleCacheRebuild()
		}
	}

	func scheduleCacheRebuild() {
		guard !cacheRebuildScheduled else { return }

		cacheRebuildScheduled = true
		cacheRebuildWorkItem?.cancel()

		let workItem = DispatchWorkItem { [weak self] in
			guard let self else { return }
			print("Executing scheduled cache rebuild...")
			self.clearAppCache()
			self.indexApplications()
			self.indexCommands()
		}

		cacheRebuildWorkItem = workItem
		DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
	}

	@objc private func handleTrayIconSettingChanged(_ notification: Notification) {
		guard let shouldShow = notification.object as? Bool else { return }
		if shouldShow {
			statusBarManager?.show()
		} else {
			statusBarManager?.hide()
		}
	}

	@objc private func handleDockIconSettingChanged(_ notification: Notification) {
		guard notification.object is Bool else { return }
		updateActivationPolicy()
	}

	@objc private func handleTrafficLightsSettingChanged(_ notification: Notification) {
		guard let shouldHide = notification.object as? Bool else { return }
		if let settingsWindow {
			setTrafficLightsVisibility(for: settingsWindow, hidden: shouldHide)
		}
	}

	@objc private func handleRefreshAppIndex() {
		print("Refreshing app index...")
		clearAppCache()
		indexApplications()
		indexCommands()
	}

	private func checkForNewApps() {
		guard let searchEngine else { return }

		DispatchQueue.global(qos: .utility).async { [weak self] in
			guard let self else { return }

			var applicationDirs = AppSettings.shared.searchFolders
			let homeApps = NSHomeDirectory() + "/Applications"
			if !applicationDirs.contains(homeApps) {
				applicationDirs.append(homeApps)
			}

			let addedCount = searchEngine.scanForNewApps(
				directories: applicationDirs,
				excludePatterns: Self.excludePatterns
			)

			if addedCount > 0 {
				print("Found \(addedCount) new app(s) - rebuilding cache...")
				DispatchQueue.main.async { [weak self] in
					self?.scheduleCacheRebuild()
				}
			}
		}
	}

	private func setTrafficLightsVisibility(for window: NSWindow, hidden: Bool) {
		window.standardWindowButton(.closeButton)?.isHidden = hidden
		window.standardWindowButton(.miniaturizeButton)?.isHidden = hidden
		window.standardWindowButton(.zoomButton)?.isHidden = hidden
	}

	private func updateActivationPolicy() {
		let settings = AppSettings.shared
		let shouldShowInDock = settings.showDockIcon || settingsWindow?.isVisible == true
		NSApp.setActivationPolicy(shouldShowInDock ? .regular : .accessory)
	}

	func toggleWindow() {
		guard let window else { return }

		if window.isVisible {
			NotificationCenter.default.post(name: .windowHidden, object: nil)
			window.orderOut(nil)

			autoreleasepool {
				clipboardManager?.cleanupOldEntries()
				IconCache.shared.clear()
				ThumbnailCache.shared.clear()
			}

			malloc_zone_pressure_relief(nil, 0)
		} else {
			checkForNewApps()
			NotificationCenter.default.post(name: .showLauncher, object: nil)
			window.makeKeyAndOrderFront(nil)
			NSApp.activate(ignoringOtherApps: true)
		}
	}

	func openClipboardManager() {
		guard let window else { return }

		if window.isVisible {
			window.orderOut(nil)
			NotificationCenter.default.post(name: .windowHidden, object: nil)
		} else {
			NotificationCenter.default.post(name: .showClipboard, object: nil)
			window.makeKeyAndOrderFront(nil)
			NSApp.activate(ignoringOtherApps: true)
		}
	}

	func openSettings() {
		showSettingsWindow()
	}

	func showSettingsWindow() {
		if settingsWindow == nil {
			let settingsView = SettingsView()

			let window = NSWindow(
				contentRect: NSRect(x: 0, y: 0, width: 900, height: 750),
				styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
				backing: .buffered,
				defer: false
			)

			window.title = "Settings"
			window.titleVisibility = .hidden
			window.titlebarAppearsTransparent = true
			window.isMovableByWindowBackground = false
			window.center()
			window.minSize = NSSize(width: 800, height: 650)
			window.contentView = NSHostingView(rootView: settingsView)
			window.isReleasedWhenClosed = false
			window.delegate = self

			setTrafficLightsVisibility(for: window, hidden: AppSettings.shared.hideTrafficLights)

			settingsWindow = window
		}

		updateActivationPolicy()
		settingsWindow?.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
	}

	private func indexApplications() {
		guard let searchEngine else { return }

		DispatchQueue.global(qos: .background).async {
			if let cachedApps = self.loadCachedApps() {
				print("Loading \(cachedApps.count) apps from cache...")

				let fileManager = FileManager.default
				var validApps: [(name: String, path: String)] = []
				var cacheInvalid = false

				for app in cachedApps {
					if fileManager.fileExists(atPath: app.path) {
						searchEngine.addApplication(id: app.path, name: app.name, path: app.path)
						validApps.append(app)
					} else {
						print("App no longer exists, invalidating cache: \(app.path)")
						cacheInvalid = true
					}
				}

				if cacheInvalid {
					print("Cache invalid - rebuilding...")
					self.clearAppCache()
					self.rebuildAppIndex()
				} else {
					print("Cache loaded. Total apps: \(searchEngine.stats().apps)")
				}
				return
			}

			self.rebuildAppIndex()
		}
	}

	private static let excludePatterns = [
		"helper", "updater", "uninstall", "crashreporter",
		"documentation", "installation notes", "sql shell",
		"reload configuration", "application stack builder",
		"pgadmin", " notes"
	]

	private func rebuildAppIndex() {
		guard let searchEngine else { return }

		print("Building app index...")

		var applicationDirs = AppSettings.shared.searchFolders
		let homeApps = NSHomeDirectory() + "/Applications"
		if !applicationDirs.contains(homeApps) {
			applicationDirs.append(homeApps)
		}

		let count = searchEngine.scanForNewApps(directories: applicationDirs, excludePatterns: Self.excludePatterns)

		let apps = searchEngine.getAllApps()
		saveCachedApps(apps)

		print("Indexing complete. Total apps: \(count)")
	}

	private func indexCommands() {
		guard let searchEngine else { return }

		for command in CommandRegistry.shared.commands {
			searchEngine.addCommand(id: command.id, name: command.name, keywords: command.keywords)
		}

		print("Indexed \(CommandRegistry.shared.commands.count) commands")
	}

	private func getAppStoragePath() -> String {
		let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
		let invokeDir = appSupportDir.appendingPathComponent("Summon")
		try? FileManager.default.createDirectory(at: invokeDir, withIntermediateDirectories: true)
		return invokeDir.appendingPathComponent("apps.rkyv").path
	}

	private func loadCachedApps() -> [(name: String, path: String)]? {
		appStorageLock.lock()
		defer { appStorageLock.unlock() }

		let storagePath = getAppStoragePath()
		guard FileManager.default.fileExists(atPath: storagePath) else {
			return nil
		}

		if appStorage == nil {
			appStorage = FFI.appStorageNew(path: storagePath)
		}

		guard let appStorage else {
			return nil
		}
		let entries = FFI.appStorageGetAll(appStorage)
		return entries.map { (name: $0.name, path: $0.path) }
	}

	private func saveCachedApps(_ apps: [(name: String, path: String)]) {
		appStorageLock.lock()
		defer { appStorageLock.unlock() }

		let storagePath = getAppStoragePath()

		if appStorage == nil {
			appStorage = FFI.appStorageNew(path: storagePath)
		}

		guard let appStorage else {
			return
		}

		_ = FFI.appStorageClear(appStorage)
		for app in apps {
			_ = FFI.appStorageAdd(appStorage, name: app.name, path: app.path)
		}
	}

	func windowWillClose(_ notification: Notification) {
		if let closingWindow = notification.object as? NSWindow,
		   closingWindow === settingsWindow
		{
			NotificationCenter.default.post(name: .closeAllDropdowns, object: nil)
			settingsWindow?.contentView = nil
			settingsWindow = nil
			updateActivationPolicy()
		}
	}
}
