import SwiftUI

enum KeyboardShortcuts {
	static let newItem = KeyEquivalent("n")
	static let newItemModifiers = EventModifiers.command

	static let closeWindow = KeyEquivalent("w")
	static let closeWindowModifiers = EventModifiers.command

	static let quitApp = KeyEquivalent("q")
	static let quitAppModifiers = EventModifiers.command

	static let cancel = KeyEquivalent("\u{1B}")
	static let cancelModifiers = EventModifiers([])

	static let settings = KeyEquivalent(",")
	static let settingsModifiers = EventModifiers.command

	static let selectAll = KeyEquivalent("a")
	static let selectAllModifiers = EventModifiers.command

	static let copy = KeyEquivalent("c")
	static let copyModifiers = EventModifiers.command

	static let paste = KeyEquivalent("v")
	static let pasteModifiers = EventModifiers.command

	static let cut = KeyEquivalent("x")
	static let cutModifiers = EventModifiers.command

	static let undo = KeyEquivalent("z")
	static let undoModifiers = EventModifiers.command

	static let delete = KeyEquivalent("\u{7F}")
	static let deleteModifiers = EventModifiers([])

	static let navigateUp = KeyEquivalent("\u{F700}")
	static let navigateUpModifiers = EventModifiers.command

	static let navigateDown = KeyEquivalent("\u{F701}")
	static let navigateDownModifiers = EventModifiers.command

	static let confirm = KeyEquivalent("\r")
	static let confirmModifiers = EventModifiers([])
}

extension View {
	func newItemShortcut() -> some View {
		keyboardShortcut(KeyboardShortcuts.newItem, modifiers: KeyboardShortcuts.newItemModifiers)
	}

	func closeWindowShortcut() -> some View {
		keyboardShortcut(KeyboardShortcuts.closeWindow, modifiers: KeyboardShortcuts.closeWindowModifiers)
	}

	func settingsShortcut() -> some View {
		keyboardShortcut(KeyboardShortcuts.settings, modifiers: KeyboardShortcuts.settingsModifiers)
	}

	func cancelShortcut() -> some View {
		keyboardShortcut(KeyboardShortcuts.cancel, modifiers: KeyboardShortcuts.cancelModifiers)
	}

	func deleteShortcut() -> some View {
		keyboardShortcut(KeyboardShortcuts.delete, modifiers: KeyboardShortcuts.deleteModifiers)
	}

	func confirmShortcut() -> some View {
		keyboardShortcut(KeyboardShortcuts.confirm, modifiers: KeyboardShortcuts.confirmModifiers)
	}
}
