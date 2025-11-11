import SwiftUI

struct SearchField: NSViewRepresentable {
	@Binding var text: String
	var placeholder: String
	var quickSelectModifier: QuickSelectModifier
	var font: NSFont
	var onSubmit: () -> Void
	var onEscape: () -> Void
	var onUpArrow: (() -> Void)?
	var onDownArrow: (() -> Void)?
	var onAltNumber: ((Int) -> Void)?

	func makeNSView(context: Context) -> NSTextField {
		let textField = CustomTextField()
		textField.delegate = context.coordinator
		textField.placeholderString = placeholder
		textField.font = font
		textField.isBordered = false
		textField.focusRingType = .none
		textField.backgroundColor = .clear
		textField.coordinator = context.coordinator
		textField.quickSelectModifier = quickSelectModifier
		textField.isAutomaticTextCompletionEnabled = false
		return textField
	}

	func updateNSView(_ nsView: NSTextField, context: Context) {
		nsView.stringValue = text
		nsView.placeholderString = placeholder
		nsView.font = font
		context.coordinator.parent = self
		if let customField = nsView as? CustomTextField {
			customField.coordinator = context.coordinator
			customField.quickSelectModifier = quickSelectModifier
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	class Coordinator: NSObject, NSTextFieldDelegate {
		var parent: SearchField

		init(_ parent: SearchField) {
			self.parent = parent
		}

		func controlTextDidChange(_ notification: Notification) {
			guard let textField = notification.object as? NSTextField else { return }
			parent.text = textField.stringValue
		}

		func control(_: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector)
			-> Bool
		{
			if commandSelector == #selector(NSResponder.insertNewline(_:)) {
				parent.onSubmit()
				return true
			}

			if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
				parent.onEscape()
				return true
			}

			if commandSelector == #selector(NSResponder.moveUp(_:)) {
				parent.onUpArrow?()
				return true
			}

			if commandSelector == #selector(NSResponder.moveDown(_:)) {
				parent.onDownArrow?()
				return true
			}

			return false
		}
	}

	class CustomTextField: NSTextField {
		weak var coordinator: Coordinator?
		var quickSelectModifier: QuickSelectModifier = .option

		override func keyDown(with event: NSEvent) {
			if let char = event.charactersIgnoringModifiers?.first {
				if event.modifierFlags.contains(.control) {
					if char == "j" || char == "n" {
						coordinator?.parent.onDownArrow?()
						return
					} else if char == "k" || char == "p" {
						coordinator?.parent.onUpArrow?()
						return
					}
				}

				if let digit = char.wholeNumberValue, digit >= 1, digit <= 9 {
					let flags = event.modifierFlags

					let triggered: Bool =
						switch quickSelectModifier {
						case .option:
							flags.contains(.option)
						case .command:
							flags.contains(.command)
						case .control:
							flags.contains(.control)
						}

					if triggered {
						coordinator?.parent.onAltNumber?(digit)
						return
					}
				}
			}

			super.keyDown(with: event)
		}
	}
}
