import AppKit
import Foundation

struct Command {
	let id: String
	let name: String
	let keywords: [String]
	let action: () -> Void
	let icon: String
}

final class CommandRegistry {
	static let shared = CommandRegistry()

	private(set) var commands: [Command] = []

	private init() {
		registerBuiltInCommands()
	}

	private func registerBuiltInCommands() {
		commands = [
			Command(
				id: "cmd_settings",
				name: "Summon Settings",
				keywords: ["settings", "preferences", "prefs", "config", "configure"],
				action: {
					NotificationCenter.default.post(name: .openSettings, object: nil)
				},
				icon: "gearshape.fill"
			),
			Command(
				id: "cmd_clipboard",
				name: "Open Clipboard History",
				keywords: ["clipboard", "history", "clips", "paste"],
				action: {
					NotificationCenter.default.post(name: .showClipboard, object: nil)
				},
				icon: "doc.on.clipboard.fill"
			),
			Command(
				id: "cmd_refresh",
				name: "Refresh App Index",
				keywords: ["refresh", "reload", "reindex", "update", "rebuild"],
				action: {
					NotificationCenter.default.post(name: .refreshAppIndex, object: nil)
				},
				icon: "arrow.clockwise"
			),
			Command(
				id: "cmd_quit",
				name: "Quit Summon",
				keywords: ["quit", "exit", "close"],
				action: {
					NSApp.terminate(nil)
				},
				icon: "power"
			)
		]
	}

	func executeCommand(id: String) {
		commands.first(where: { $0.id == id })?.action()
	}
}
