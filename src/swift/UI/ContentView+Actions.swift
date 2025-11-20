import Carbon
import SwiftUI

extension ContentView {
	func handleAltNumber(_ number: Int) {
		let index = number - 1
		guard index >= 0, index < results.count else { return }
		selectedIndex = index
		launchSelected()
	}

	func handleSaveAsSnippet() {
		guard isClipboardMode, selectedIndex < clipboardHistory.count else { return }
		let entry = clipboardHistory[selectedIndex]

		guard entry.type == .text else { return }

		NotificationCenter.default.post(
			name: .saveClipboardAsSnippet,
			object: nil,
			userInfo: ["content": entry.content]
		)

		NSApp.keyWindow?.orderOut(nil)
	}

	func handleTogglePin() {
		guard !isClipboardMode, selectedIndex < results.count else { return }
		let result = results[selectedIndex]

		guard result.isApp || result.isCommand else { return }

		let identifier: String
		if result.isCommand {
			identifier = result.id
		} else {
			guard let path = result.path else { return }
			identifier = path
		}

		if settings.pinnedApps.contains(where: { $0.path == identifier }) {
			settings.pinnedApps.removeAll(where: { $0.path == identifier })
		} else {
			settings.pinnedApps.append(
				RecentApp(
					name: result.name, path: identifier, timestamp: Date().timeIntervalSince1970
				))
		}
		settings.save()
		performSearch(searchText)
	}

	func handleShowInFinder() {
		guard !isClipboardMode, selectedIndex < results.count else { return }
		let result = results[selectedIndex]

		guard result.isApp, let path = result.path else { return }

		NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
	}

	func handleGetInfo() {
		guard !isClipboardMode, selectedIndex < results.count else { return }
		let result = results[selectedIndex]

		guard result.isApp, let path = result.path else { return }

		let fileManager = FileManager.default
		var totalSize: UInt64 = 0

		if let enumerator = fileManager.enumerator(
			at: URL(fileURLWithPath: path),
			includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
		) {
			for case let fileURL as URL in enumerator {
				if let resourceValues = try? fileURL.resourceValues(forKeys: [
					.fileSizeKey, .isRegularFileKey
				]),
					let isRegularFile = resourceValues.isRegularFile,
					isRegularFile,
					let fileSize = resourceValues.fileSize
				{
					totalSize += UInt64(fileSize)
				}
			}
		}

		let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)

		var version: String?
		if let bundle = Bundle(path: path),
		   let ver = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
		{
			version = ver
		}

		selectedAppInfo = AppInfo(name: result.name, path: path, size: sizeStr, version: version)
	}

	func handleCopyPath() {
		guard !isClipboardMode, selectedIndex < results.count else { return }
		let result = results[selectedIndex]

		guard result.isApp, let path = result.path else { return }

		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(path, forType: .string)
	}

	func handleQuitApp(force: Bool = false) {
		guard !isClipboardMode, selectedIndex < results.count else { return }
		let result = results[selectedIndex]

		guard result.isApp, let path = result.path else { return }

		if let app = NSWorkspace.shared.runningApplications.first(where: {
			$0.bundleURL?.path == path
		}) {
			if force {
				app.forceTerminate()
			} else {
				app.terminate()
			}
		}
	}

	func handleHideApp() {
		guard !isClipboardMode, selectedIndex < results.count else { return }
		let result = results[selectedIndex]

		guard result.isApp, let path = result.path else { return }

		if let app = NSWorkspace.shared.runningApplications.first(where: {
			$0.bundleURL?.path == path
		}) {
			app.hide()
		}
	}

	func loadAppIcon() {
		if let icon = NSImage(named: "AppIcon") {
			appIcon = icon
		} else {
			appIcon = NSImage(systemSymbolName: "app.badge", accessibilityDescription: "Summon")
		}
	}

	func handleSaveImage() {
		guard isClipboardMode, selectedIndex < clipboardHistory.count else { return }
		let entry = clipboardHistory[selectedIndex]

		guard entry.type == .image, let imagePath = entry.imageFilePath else { return }

		let saveDirectory: URL =
			if !settings.imageSavePath.isEmpty,
			FileManager.default.fileExists(atPath: settings.imageSavePath) {
				URL(fileURLWithPath: settings.imageSavePath)
			} else {
				StoragePathManager.getPicturesDirectory()
			}

		let timestamp = Int(Date().timeIntervalSince1970)
		let fileName = "Screenshot_\(timestamp).png"
		let fileURL = saveDirectory.appendingPathComponent(fileName)

		do {
			let sourceURL = URL(fileURLWithPath: imagePath)
			try FileManager.default.copyItem(at: sourceURL, to: fileURL)
			NSWorkspace.shared.activateFileViewerSelecting([fileURL])
		} catch {
			print("Failed to save image: \(error)")
		}

		NSApp.keyWindow?.orderOut(nil)
	}

	func handleDeleteClipboardEntry() {
		guard isClipboardMode, selectedIndex < clipboardHistory.count else { return }

		clipboardCoordinator.removeEntry(at: selectedIndex)

		if selectedIndex >= clipboardHistory.count, selectedIndex > 0 {
			selectedIndex -= 1
		}

		performSearch(searchText)
	}

	func matchesShortcut(_ event: NSEvent, _ shortcut: KeyboardShortcut) -> Bool {
		guard event.keyCode == UInt16(shortcut.keyCode) else { return false }

		let flags = event.modifierFlags
		let hasCmd = flags.contains(.command)
		let hasOpt = flags.contains(.option)
		let hasShift = flags.contains(.shift)
		let hasCtrl = flags.contains(.control)

		let wantsCmd = shortcut.modifiers & UInt32(cmdKey) != 0
		let wantsOpt = shortcut.modifiers & UInt32(optionKey) != 0
		let wantsShift = shortcut.modifiers & UInt32(shiftKey) != 0
		let wantsCtrl = shortcut.modifiers & UInt32(controlKey) != 0

		return hasCmd == wantsCmd && hasOpt == wantsOpt && hasShift == wantsShift
			&& hasCtrl == wantsCtrl
	}

	func setupEventMonitor() {
		eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) {
			[self] event in
			self.handleKeyEvent(event)
		}
	}

	func removeEventMonitor() {
		if let monitor = eventMonitor {
			NSEvent.removeMonitor(monitor)
			eventMonitor = nil
		}
	}

	func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
		if event.type == .flagsChanged {
			let optionPressed = event.modifierFlags.contains(.option)
			if showSecondaryHints != optionPressed {
				showSecondaryHints = optionPressed
			}
			return event
		}

		guard !isSettingsWindowActive() else { return event }

		if let handled = handleClipboardShortcuts(event) { return handled }
		if let handled = handleAppShortcuts(event) { return handled }
		if let handled = handleQuickSelect(event) { return handled }

		return event
	}

	func isSettingsWindowActive() -> Bool {
		guard let keyWindow = NSApp.keyWindow else { return false }
		return keyWindow.title == "Settings"
			|| keyWindow.contentView?.subviews.contains {
				String(describing: type(of: $0)).contains("SettingsView")
			} ?? false
	}

	func handleClipboardShortcuts(_ event: NSEvent) -> NSEvent? {
		guard isClipboardMode else { return nil }
		guard selectedIndex < clipboardHistory.count else { return nil }

		if matchesShortcut(event, settings.deleteClipboardShortcut) {
			handleDeleteClipboardEntry()
			return nil
		}

		if matchesShortcut(event, settings.saveClipboardShortcut) {
			let entry = clipboardHistory[selectedIndex]
			switch entry.type {
			case .text: handleSaveAsSnippet()
			case .image: handleSaveImage()
			case .unknown: break
			}
			return nil
		}

		return nil
	}

	func handleAppShortcuts(_ event: NSEvent) -> NSEvent? {
		if matchesShortcut(event, settings.clearQueryHistoryShortcut) {
			handleClearQueryHistory()
			return nil
		}

		guard !isClipboardMode else { return nil }

		if matchesShortcut(event, settings.pinAppShortcut) {
			handleTogglePin()
			return nil
		} else if matchesShortcut(event, settings.revealAppShortcut) {
			handleShowInFinder()
			return nil
		} else if matchesShortcut(event, settings.copyPathShortcut) {
			handleCopyPath()
			return nil
		} else if matchesShortcut(event, settings.forceQuitShortcut) {
			handleQuitApp(force: true)
			return nil
		} else if matchesShortcut(event, settings.quitAppShortcut) {
			handleQuitApp(force: false)
			return nil
		} else if matchesShortcut(event, settings.hideAppShortcut) {
			handleHideApp()
			return nil
		} else if matchesShortcut(event, settings.getInfoShortcut) {
			handleGetInfo()
			return nil
		}
		return nil
	}

	func handleClearQueryHistory() {
		QueryHistoryManager.shared.clearHistory()
		historyNavigationIndex = nil
		historyQueries = []
		currentEditedQuery = ""
	}

	func handleQuickSelect(_ event: NSEvent) -> NSEvent? {
		guard let char = event.charactersIgnoringModifiers?.first,
		      let digit = char.wholeNumberValue,
		      digit >= 1, digit <= 9
		else { return nil }

		let shouldTrigger: Bool =
			switch settings.quickSelectModifier {
			case .option: event.modifierFlags.contains(.option)
			case .command: event.modifierFlags.contains(.command)
			case .control: event.modifierFlags.contains(.control)
			}

		guard shouldTrigger else { return nil }
		handleAltNumber(digit)
		return nil
	}

	func handleUpArrow() {
		guard !isClipboardMode else {
			if selectedIndex > 0 { selectedIndex -= 1 }
			return
		}

		if searchText.isEmpty, results.isEmpty || selectedIndex == 0 {
			if let lastQuery = QueryHistoryManager.shared.getLastQuery() {
				searchText = lastQuery
				historyNavigationIndex = 0
				return
			}
		}

		if historyNavigationIndex == nil {
			currentEditedQuery = searchText
			historyQueries = QueryHistoryManager.shared.getAllQueries()
		}

		if let currentIndex = historyNavigationIndex {
			let nextIndex = currentIndex + 1
			if nextIndex < historyQueries.count {
				historyNavigationIndex = nextIndex
				searchText = historyQueries[nextIndex]
			}
		} else if !historyQueries.isEmpty {
			historyNavigationIndex = 0
			searchText = historyQueries[0]
		}

		if historyNavigationIndex != nil { return }
		if selectedIndex > 0 { selectedIndex -= 1 }
	}

	func handleDownArrow() {
		guard !isClipboardMode else {
			if selectedIndex < results.count - 1 { selectedIndex += 1 }
			return
		}

		if let currentIndex = historyNavigationIndex {
			if currentIndex > 0 {
				historyNavigationIndex = currentIndex - 1
				searchText = historyQueries[currentIndex - 1]
			} else {
				historyNavigationIndex = nil
				searchText = currentEditedQuery
				currentEditedQuery = ""
			}
			return
		}

		if selectedIndex < results.count - 1 { selectedIndex += 1 }
	}
}
