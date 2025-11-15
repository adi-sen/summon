import Cocoa

class StatusBarManager {
	private var statusItem: NSStatusItem?
	var onToggle: (() -> Void)?
	var onSettings: (() -> Void)?
	var onExtensions: (() -> Void)?
	var onClearClipboard: (() -> Void)?
	var onQuit: (() -> Void)?

	func setup() {
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

		if let button = statusItem?.button {
			if let resourcePath = Bundle.main.resourcePath,
			   let icon = NSImage(contentsOfFile: resourcePath + "/AppIcon.icns")
			{
				let resizedIcon = NSImage(size: NSSize(width: 18, height: 18))
				resizedIcon.lockFocus()
				icon.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
				resizedIcon.unlockFocus()
				button.image = resizedIcon
			} else if let icon = NSImage(named: "AppIcon") {
				let resizedIcon = NSImage(size: NSSize(width: 18, height: 18))
				resizedIcon.lockFocus()
				icon.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
				resizedIcon.unlockFocus()
				button.image = resizedIcon
			} else {
				button.image = NSImage(systemSymbolName: "app.badge", accessibilityDescription: "Summon")
			}
			button.action = #selector(statusBarButtonClicked)
			button.target = self
		}

		setupMenu()
	}

	private func setupMenu() {
		let menu = NSMenu()

		let aboutItem = NSMenuItem(title: "About Summon", action: #selector(showAbout), keyEquivalent: "")
		aboutItem.target = self

		let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkUpdates), keyEquivalent: "")
		updateItem.target = self

		let showItem = NSMenuItem(title: "Toggle Launcher", action: #selector(toggleLauncher), keyEquivalent: "")
		showItem.target = self

		let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
		settingsItem.target = self

		let extensionsItem = NSMenuItem(title: "Extensions", action: #selector(openExtensions), keyEquivalent: "")
		extensionsItem.target = self

		let clearClipboardItem = NSMenuItem(
			title: "Clear Clipboard History",
			action: #selector(clearClipboard),
			keyEquivalent: ""
		)
		clearClipboardItem.target = self

		let quitItem = NSMenuItem(title: "Quit Summon", action: #selector(quitApp), keyEquivalent: "")
		quitItem.target = self

		menu.addItem(aboutItem)
		menu.addItem(updateItem)
		menu.addItem(NSMenuItem.separator())
		menu.addItem(showItem)
		menu.addItem(NSMenuItem.separator())
		menu.addItem(settingsItem)
		menu.addItem(extensionsItem)
		menu.addItem(NSMenuItem.separator())
		menu.addItem(clearClipboardItem)
		menu.addItem(NSMenuItem.separator())
		menu.addItem(quitItem)

		statusItem?.menu = menu
	}

	@objc private func statusBarButtonClicked() {
		onToggle?()
	}

	@objc private func toggleLauncher() {
		onToggle?()
	}

	@objc private func openSettings() {
		onSettings?()
	}

	@objc private func openExtensions() {
		onExtensions?()
	}

	@objc private func clearClipboard() {
		onClearClipboard?()
	}

	@objc private func showAbout() {
		let alert = NSAlert()
		alert.messageText = "Summon"
		alert.informativeText = "Version 0.0.1\n\nA fast, efficient launcher for macOS"
		alert.alertStyle = .informational
		alert.addButton(withTitle: "OK")
		alert.runModal()
	}

	@objc private func checkUpdates() {
		let alert = NSAlert()
		alert.messageText = "Check for Updates"
		alert.informativeText = "Update checking not yet implemented"
		alert.alertStyle = .informational
		alert.addButton(withTitle: "OK")
		alert.runModal()
	}

	@objc private func quitApp() {
		onQuit?()
	}

	func hide() {
		if let statusItem {
			NSStatusBar.system.removeStatusItem(statusItem)
			self.statusItem = nil
		}
	}

	func show() {
		if statusItem == nil {
			setup()
		}
	}
}
