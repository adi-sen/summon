import SwiftUI

struct Button: View {
	let title: String
	let icon: String?
	let action: () -> Void
	let style: Style
	let size: Size
	let fullWidth: Bool
	@EnvironmentObject var settings: AppSettings

	enum Style {
		case primary
		case secondary
		case success
		case danger
		case plain
	}

	enum Size {
		case small
		case medium
		case large

		var fontSize: CGFloat {
			switch self {
			case .small: DesignTokens.Typography.small
			case .medium: DesignTokens.Typography.body
			case .large: DesignTokens.Typography.title
			}
		}

		var iconSize: CGFloat {
			switch self {
			case .small: DesignTokens.Typography.iconSmall
			case .medium: DesignTokens.Typography.icon
			case .large: DesignTokens.Typography.iconLarge
			}
		}

		var horizontalPadding: CGFloat {
			switch self {
			case .small: DesignTokens.Spacing.md
			case .medium: DesignTokens.Spacing.xl
			case .large: DesignTokens.Spacing.xxl
			}
		}

		var verticalPadding: CGFloat {
			switch self {
			case .small: DesignTokens.Spacing.sm
			case .medium: DesignTokens.Spacing.md + 2
			case .large: DesignTokens.Spacing.lg
			}
		}
	}

	init(
		_ title: String,
		icon: String? = nil,
		style: Style = .primary,
		size: Size = .medium,
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
		SwiftUI.Button(action: action) {
			HStack(spacing: icon != nil ? 6 : 0) {
				if let icon {
					Image(systemName: icon)
						.font(Font(settings.uiFont.withSize(size.iconSize)))
				}
				Text(title)
					.font(Font(settings.uiFont.withSize(size.fontSize)))
			}
			.foregroundColor(foregroundColor)
			.padding(.horizontal, size.horizontalPadding)
			.padding(.vertical, size.verticalPadding)
			.frame(maxWidth: fullWidth ? .infinity : nil)
			.background(backgroundColor)
			.cornerRadius(DesignTokens.CornerRadius.md)
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

struct IconButton: View {
	let icon: String
	let action: () -> Void
	let size: CGFloat
	let color: Color?
	@EnvironmentObject var settings: AppSettings

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
		SwiftUI.Button(action: action) {
			Image(systemName: icon)
				.font(Font(settings.uiFont.withSize(size)))
				.foregroundColor(color ?? settings.secondaryTextColorUI)
		}
		.buttonStyle(PlainButtonStyle())
	}
}
