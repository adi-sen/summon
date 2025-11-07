import Carbon
import Cocoa

class SnippetExpander {
	static let shared = SnippetExpander()

	private var eventTap: CFMachPort?
	private var runLoopSource: CFRunLoopSource?
	private var currentBuffer: String = ""
	private let manager = SnippetManager.shared

	private let maxBufferLength = 50 // Max trigger length to track

	// Static keycode map for O(1) lookup instead of O(n) switch statement
	private static let keyCodeMap: [Character: Int] = [
		"a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
		"e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
		"i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
		"m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
		"q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
		"u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
		"y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
		"0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
		"4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
		"8": kVK_ANSI_8, "9": kVK_ANSI_9,
		" ": kVK_Space, ".": kVK_ANSI_Period, ",": kVK_ANSI_Comma,
		"/": kVK_ANSI_Slash, ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote,
		"[": kVK_ANSI_LeftBracket, "]": kVK_ANSI_RightBracket,
		"\\": kVK_ANSI_Backslash, "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal,
		"`": kVK_ANSI_Grave
	]

	func start() {
		guard checkAccessibilityPermissions() else {
			print("Snippet expansion requires accessibility permissions")
			return
		}

		let eventMask = (1 << CGEventType.keyDown.rawValue)
		guard
			let tap = CGEvent.tapCreate(
				tap: .cgSessionEventTap,
				place: .headInsertEventTap,
				options: .defaultTap,
				eventsOfInterest: CGEventMask(eventMask),
				callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
					guard let refcon else { return Unmanaged.passRetained(event) }
					let expander = Unmanaged<SnippetExpander>.fromOpaque(refcon)
						.takeUnretainedValue()
					return expander.handleKeyEvent(proxy: proxy, type: type, event: event)
				},
				userInfo: Unmanaged.passUnretained(self).toOpaque()
			)
		else {
			print("Failed to create event tap for snippet expansion")
			return
		}

		eventTap = tap
		runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
		CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
		CGEvent.tapEnable(tap: tap, enable: true)

		print("Snippet expansion enabled")
	}

	func stop() {
		if let tap = eventTap {
			CGEvent.tapEnable(tap: tap, enable: false)
			CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
			eventTap = nil
			runLoopSource = nil
		}
		currentBuffer = ""
		print("Snippet expansion disabled")
	}

	private func handleKeyEvent(proxy _: CGEventTapProxy, type: CGEventType, event: CGEvent)
		-> Unmanaged<CGEvent>?
	{
		guard type == .keyDown else {
			return Unmanaged.passRetained(event)
		}

		// Don't expand snippets if we're in our own settings window
		if let keyWindow = NSApp.keyWindow, keyWindow.title == "Settings" {
			return Unmanaged.passRetained(event)
		}

		let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

		if let character = getCharacter(from: event) {
			if keyCode == kVK_Delete || keyCode == kVK_ForwardDelete {
				if !currentBuffer.isEmpty {
					currentBuffer.removeLast()
				}
				return Unmanaged.passRetained(event)
			} else if keyCode == kVK_Return || keyCode == kVK_Escape || keyCode == kVK_Tab {
				currentBuffer = ""
				return Unmanaged.passRetained(event)
			} else if keyCode == kVK_Space {
				let result = checkAndExpandSnippet()
				currentBuffer = "" // Clear buffer after space
				if result {
					return nil // Suppress the space if we expanded
				}
				return Unmanaged.passRetained(event)
			}

			currentBuffer.append(character)

			if currentBuffer.count > maxBufferLength {
				currentBuffer = String(currentBuffer.suffix(maxBufferLength))
			}

			_ = checkAndExpandSnippet()
		}

		return Unmanaged.passRetained(event)
	}

	private func checkAndExpandSnippet() -> Bool {
		if let match = manager.findMatch(in: currentBuffer) {
			expandSnippet(trigger: match.trigger, content: match.content)
			return true
		}
		return false
	}

	private func expandSnippet(trigger: String, content: String) {
		for _ in 0 ..< trigger.count {
			sendKeyPress(keyCode: kVK_Delete, modifiers: [])
		}

		pasteText(content)

		currentBuffer = ""
	}

	private func sendKeyPress(keyCode: Int, modifiers: CGEventFlags) {
		let keyDownEvent = CGEvent(
			keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true
		)
		let keyUpEvent = CGEvent(
			keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: false
		)

		keyDownEvent?.flags = modifiers
		keyUpEvent?.flags = modifiers

		keyDownEvent?.post(tap: .cghidEventTap)
		keyUpEvent?.post(tap: .cghidEventTap)
	}

	private func typeText(_ text: String) {
		for char in text {
			if let keyCode = characterToKeyCode(char) {
				let needsShift = char.isUppercase || "!@#$%^&*()_+{}|:\"<>?".contains(char)
				let modifiers: CGEventFlags = needsShift ? .maskShift : []
				sendKeyPress(keyCode: keyCode, modifiers: modifiers)
				usleep(1000) // 1ms delay between characters (optimized from 5ms)
			} else {
				pasteText(String(char))
			}
		}
	}

	private func pasteText(_ text: String) {
		let pasteboard = NSPasteboard.general
		let oldContents = pasteboard.string(forType: .string)

		pasteboard.clearContents()
		pasteboard.setString(text, forType: .string)

		sendKeyPress(keyCode: kVK_ANSI_V, modifiers: .maskCommand)

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
			if let old = oldContents {
				pasteboard.clearContents()
				pasteboard.setString(old, forType: .string)
			}
		}
	}

	private func getCharacter(from event: CGEvent) -> Character? {
		let maxLength = 16
		var actualLength = 0
		var chars = [UniChar](repeating: 0, count: maxLength)

		event.keyboardGetUnicodeString(
			maxStringLength: maxLength, actualStringLength: &actualLength, unicodeString: &chars
		)

		if actualLength > 0 {
			let string = String(utf16CodeUnits: chars, count: actualLength)
			return string.first
		}
		return nil
	}

	private func characterToKeyCode(_ char: Character) -> Int? {
		let lower = char.lowercased().first ?? char
		return Self.keyCodeMap[lower]
	}

	private func checkAccessibilityPermissions() -> Bool {
		let options: NSDictionary = [
			kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
		]
		return AXIsProcessTrustedWithOptions(options)
	}
}
