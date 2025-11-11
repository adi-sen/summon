import SwiftUI

/// A generalized styled button component supporting common button patterns.
/// Provides consistent styling across the application with configurable styles and layouts.
struct StyledButton: View {
	let title: String
	let icon: String?
	let action: () -> Void
	let style: ButtonStyle
	let size: ButtonSize
	let fullWidth: Bool
	@ObservedObject var settings = AppSettings.shared

	enum ButtonStyle {
		case primary
		case secondary
		case success
		case danger
		case plain
	}

	enum ButtonSize {
		case small
		case medium
		case large

		var fontSize: CGFloat {
			switch self {
			case .small: 11
			case .medium: 13
			case .large: 14
			}
		}

		var iconSize: CGFloat {
			switch self {
			case .small: 11
			case .medium: 14
			case .large: 16
			}
		}

		var horizontalPadding: CGFloat {
			switch self {
			case .small: 8
			case .medium: 16
			case .large: 20
			}
		}

		var verticalPadding: CGFloat {
			switch self {
			case .small: 6
			case .medium: 10
			case .large: 12
			}
		}
	}

	init(
		_ title: String,
		icon: String? = nil,
		style: ButtonStyle = .primary,
		size: ButtonSize = .medium,
		fullWidth: Bool = false,
		action: @escaping () -> Void
	) {
		self.title = title
		self.icon = icon
		self.style = style
		self.size = size
		self.fullWidth = fullWidth
		self.action = action
	}

	var body: some View {
		Button(action: action) {
			HStack(spacing: icon != nil ? 6 : 0) {
				if let icon {
					Image(systemName: icon)
						.font(.system(size: size.iconSize))
				}
				Text(title)
					.font(Font(settings.uiFont.withSize(size.fontSize)))
			}
			.foregroundColor(foregroundColor)
			.padding(.horizontal, size.horizontalPadding)
			.padding(.vertical, size.verticalPadding)
			.frame(maxWidth: fullWidth ? .infinity : nil)
			.background(backgroundColor)
			.cornerRadius(6)
		}
		.buttonStyle(PlainButtonStyle())
	}

	private var foregroundColor: Color {
		switch style {
		case .primary:
			Color.white
		case .secondary:
			settings.textColorUI
		case .success:
			Color.white
		case .danger:
			Color.white
		case .plain:
			settings.textColorUI
		}
	}

	private var backgroundColor: Color {
		switch style {
		case .primary:
			settings.accentColorUI
		case .secondary:
			settings.searchBarColorUI
		case .success:
			Color.green.opacity(0.8)
		case .danger:
			Color.red.opacity(0.8)
		case .plain:
			settings.metadataColorUI
		}
	}
}

/// Icon-only button variant
struct IconButton: View {
	let icon: String
	let action: () -> Void
	let size: CGFloat
	let color: Color?
	@ObservedObject var settings = AppSettings.shared

	init(
		icon: String,
		size: CGFloat = 18,
		color: Color? = nil,
		action: @escaping () -> Void
	) {
		self.icon = icon
		self.size = size
		self.color = color
		self.action = action
	}

	var body: some View {
		Button(action: action) {
			Image(systemName: icon)
				.font(.system(size: size))
				.foregroundColor(color ?? settings.secondaryTextColorUI)
		}
		.buttonStyle(PlainButtonStyle())
	}
}
