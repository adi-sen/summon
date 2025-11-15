import SwiftUI

struct ExtensionButton: View {
	let icon: String
	let title: String
	let action: () -> Void
	let style: ButtonStyle

	enum ButtonStyle {
		case primary
		case secondary
		case success

		var buttonStyle: Button.Style {
			switch self {
			case .primary: .primary
			case .secondary: .secondary
			case .success: .success
			}
		}
	}

	var body: some View {
		Button(
			title,
			icon: icon,
			style: style.buttonStyle,
			fullWidth: true,
			action: action
		)
	}
}
