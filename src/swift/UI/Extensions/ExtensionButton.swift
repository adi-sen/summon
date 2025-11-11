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

		var styledButtonStyle: StyledButton.ButtonStyle {
			switch self {
			case .primary: .primary
			case .secondary: .secondary
			case .success: .success
			}
		}
	}

	var body: some View {
		StyledButton(
			title,
			icon: icon,
			style: style.styledButtonStyle,
			fullWidth: true,
			action: action
		)
	}
}
