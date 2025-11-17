import Carbon
import Foundation

enum ShortcutManager {
	private static let keyCodeMap: [String: Int] = [
		"space": kVK_Space,
		"esc": kVK_Escape,
		"return": kVK_Return,
		"tab": kVK_Tab,
		"delete": kVK_Delete,
		"left": kVK_LeftArrow,
		"right": kVK_RightArrow,
		"up": kVK_UpArrow,
		"down": kVK_DownArrow,
		"a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
		"e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
		"i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
		"m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
		"q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
		"u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
		"y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
		"0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
		"4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
		"8": kVK_ANSI_8, "9": kVK_ANSI_9
	]

	private static let reverseMap: [Int: String] = Dictionary(
		uniqueKeysWithValues: keyCodeMap.map { ($1, $0) }
	)

	static func keyCode(from string: String) -> UInt32? {
		keyCodeMap[string.lowercased()].map(UInt32.init)
	}

	static func string(from keyCode: UInt32) -> String {
		reverseMap[Int(keyCode)] ?? "space"
	}

	static func encode(_ shortcut: KeyboardShortcut) -> (key: String, mods: [String]) {
		let key = string(from: shortcut.keyCode)
		var mods: [String] = []

		if shortcut.modifiers & UInt32(cmdKey) != 0 {
			mods.append("command")
		}
		if shortcut.modifiers & UInt32(optionKey) != 0 {
			mods.append("option")
		}
		if shortcut.modifiers & UInt32(shiftKey) != 0 {
			mods.append("shift")
		}
		if shortcut.modifiers & UInt32(controlKey) != 0 {
			mods.append("control")
		}

		return (key, mods)
	}

	static func decode(key: String, mods: [String]) -> KeyboardShortcut? {
		guard let keyCode = keyCode(from: key) else { return nil }

		var modifierFlags: UInt32 = 0
		for mod in mods {
			switch mod.lowercased() {
			case "command":
				modifierFlags |= UInt32(cmdKey)
			case "option":
				modifierFlags |= UInt32(optionKey)
			case "shift":
				modifierFlags |= UInt32(shiftKey)
			case "control":
				modifierFlags |= UInt32(controlKey)
			default:
				break
			}
		}

		return KeyboardShortcut(keyCode: keyCode, modifiers: modifierFlags)
	}
}
