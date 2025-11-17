import AppKit
import SwiftUI

struct AppInfo {
	let name: String
	let path: String
	let size: String
	let version: String?
}

class AppManagementCoordinator: ObservableObject {
	@Published var selectedAppInfo: AppInfo?
	@Published var showSecondaryHints = false
	@Published var appIcon: NSImage?

	private let settings: AppSettings

	init(settings: AppSettings) {
		self.settings = settings
	}

	func isAppRunning(path: String) -> Bool {
		NSWorkspace.shared.runningApplications.contains { app in
			app.bundleURL?.path == path
		}
	}

	func getAppHints(for result: CategoryResult, identifier: String, pinnedApps: [RecentApp]) -> [HintAction] {
		let isCommand = result.category == "Command"
		let isPinned = pinnedApps.contains { $0.path == identifier }

		if isCommand {
			return [
				HintAction(
					shortcut: settings.pinAppShortcut.displayString,
					label: isPinned ? "Unpin" : "Pin",
					action: {}
				)
			]
		}

		let running = isAppRunning(path: identifier)

		if showSecondaryHints {
			var hints: [HintAction] = [
				HintAction(
					shortcut: settings.copyPathShortcut.displayString,
					label: "Copy Path",
					action: {}
				)
			]
			if running {
				hints.insert(
					HintAction(
						shortcut: settings.quitAppShortcut.displayString,
						label: "Quit App",
						action: {}
					),
					at: 0
				)
				hints.insert(
					HintAction(
						shortcut: settings.hideAppShortcut.displayString,
						label: "Hide App",
						action: {}
					),
					at: 1
				)
			}
			return hints
		} else {
			var hints: [HintAction] = []
			if running {
				hints.append(
					HintAction(
						shortcut: settings.quitAppShortcut.displayString,
						label: "Quit",
						action: {}
					))
				hints.append(
					HintAction(
						shortcut: settings.hideAppShortcut.displayString,
						label: "Hide",
						action: {}
					))
			}
			hints.append(
				HintAction(
					shortcut: settings.pinAppShortcut.displayString,
					label: isPinned ? "Unpin" : "Pin",
					action: {}
				))
			hints.append(
				HintAction(
					shortcut: settings.copyPathShortcut.displayString,
					label: "More...",
					action: {}
				))
			return hints
		}
	}

	func loadAppInfo(for identifier: String) {
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			guard let bundle = Bundle(path: identifier) else { return }

			let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
				?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
				?? URL(fileURLWithPath: identifier).deletingPathExtension().lastPathComponent

			let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

			var size = "Unknown"
			if let resourceValues = try? URL(fileURLWithPath: identifier).resourceValues(forKeys: [
				.totalFileSizeKey
			]),
				let totalSize = resourceValues.totalFileSize
			{
				size = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
			}

			let appIcon = NSWorkspace.shared.icon(forFile: identifier)

			DispatchQueue.main.async {
				self?.selectedAppInfo = AppInfo(
					name: name,
					path: identifier,
					size: size,
					version: version
				)
				self?.appIcon = appIcon
			}
		}
	}

	func clearAppInfo() {
		selectedAppInfo = nil
		appIcon = nil
	}

	func toggleSecondaryHints() {
		showSecondaryHints.toggle()
	}
}
