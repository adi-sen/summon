import Cocoa

class StatusBarManager {
	private var statusItem: NSStatusItem?
	var onToggle: (() -> Void)?
	var onSettings: (() -> Void)?
	var onQuit: (() -> Void)?

	func setup() {
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

		if let button = statusItem?.button {
			button.image = NSImage(systemSymbolName: "command.circle", accessibilityDescription: "Launcher")
			button.action = #selector(statusBarButtonClicked)
			button.target = self
		}

		setupMenu()
	}

	private func setupMenu() {
		let menu = NSMenu()

		let settings = AppSettings.shared
		let shortcut = settings.launcherShortcut
		let shortcutDisplay = shortcut.displayString

		let showItem = NSMenuItem(title: "Toggle Summon", action: #selector(toggleLauncher), keyEquivalent: "")
		showItem.target = self

		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.tabStops = [NSTextTab(textAlignment: .right, location: 200)]

		let attributedTitle = NSMutableAttributedString(string: "Toggle Summon\t\(shortcutDisplay)")
		attributedTitle.addAttribute(
			.paragraphStyle,
			value: paragraphStyle,
			range: NSRange(location: 0, length: attributedTitle.length)
		)
		showItem.attributedTitle = attributedTitle

		let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
		settingsItem.target = self

		let quitItem = NSMenuItem(title: "Quit Summon", action: #selector(quitApp), keyEquivalent: "q")
		quitItem.target = self

		menu.addItem(showItem)
		menu.addItem(NSMenuItem.separator())
		menu.addItem(settingsItem)
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
