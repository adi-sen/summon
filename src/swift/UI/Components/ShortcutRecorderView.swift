import Carbon
import SwiftUI

struct ShortcutRecorderView: View {
	let label: String
	@Binding var shortcut: KeyboardShortcut
	@EnvironmentObject var settings: AppSettings
	@State private var isRecording = false
	@FocusState private var isFocused: Bool

	var body: some View {
		HStack {
			Text(label)
				.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
				.foregroundColor(settings.textColorUI)

			Spacer()

			SwiftUI.Button(action: {
				isRecording.toggle()
				isFocused = isRecording
			}) {
				Text(isRecording ? "Press keys..." : shortcut.displayString)
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
					.foregroundColor(isRecording ? settings.accentColorUI : settings.secondaryTextColorUI)
					.padding(.horizontal, DesignTokens.Spacing.lg)
					.padding(.vertical, DesignTokens.Spacing.sm)
					.background(
						RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
							.fill(settings.metadataColorUI)
							.overlay(
								RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
									.stroke(isRecording ? settings.accentColorUI : Color.clear, lineWidth: 2)
							)
					)
			}
			.buttonStyle(PlainButtonStyle())
			.focused($isFocused)
			.background(KeyEventView(isRecording: $isRecording, shortcut: $shortcut))
		}
		.padding(.vertical, DesignTokens.Spacing.xxs)
	}
}

struct KeyEventView: NSViewRepresentable {
	@Binding var isRecording: Bool
	@Binding var shortcut: KeyboardShortcut

	func makeNSView(context _: Context) -> NSView {
		let view = KeyCaptureView()
		view.onKeyEvent = { keyCode, modifiers in
			if isRecording {
				if keyCode != 0, modifiers != 0 {
					shortcut = KeyboardShortcut(
						keyCode: UInt32(keyCode), modifiers: UInt32(modifiers)
					)
					isRecording = false
					AppSettings.shared.scheduleSave()
				}
			}
		}
		return view
	}

	func updateNSView(_ nsView: NSView, context _: Context) {
		guard let view = nsView as? KeyCaptureView else { return }

		if isRecording {
			DispatchQueue.main.async {
				nsView.window?.makeFirstResponder(view)
			}
		}
	}
}

class KeyCaptureView: NSView {
	var onKeyEvent: ((UInt16, Int) -> Void)?

	override var acceptsFirstResponder: Bool { true }

	override func keyDown(with event: NSEvent) {
		let keyCode = event.keyCode
		var modifiers = 0

		if event.modifierFlags.contains(.command) {
			modifiers |= cmdKey
		}
		if event.modifierFlags.contains(.option) {
			modifiers |= optionKey
		}
		if event.modifierFlags.contains(.shift) {
			modifiers |= shiftKey
		}
		if event.modifierFlags.contains(.control) {
			modifiers |= controlKey
		}

		onKeyEvent?(keyCode, modifiers)
	}

	override func flagsChanged(with _: NSEvent) {}
}
