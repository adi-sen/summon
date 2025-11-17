import SwiftUI

enum TextStyle {
	case small
	case body
	case title
	case large

	var size: CGFloat {
		switch self {
		case .small: return DesignTokens.Typography.small
		case .body: return DesignTokens.Typography.body
		case .title: return DesignTokens.Typography.title
		case .large: return DesignTokens.Typography.large
		}
	}
}

struct Spacing {
	let horizontal: CGFloat
	let vertical: CGFloat

	static let small = Spacing(horizontal: DesignTokens.Spacing.sm, vertical: DesignTokens.Spacing.sm)
	static let medium = Spacing(horizontal: DesignTokens.Spacing.md, vertical: DesignTokens.Spacing.md)
	static let large = Spacing(horizontal: DesignTokens.Spacing.lg, vertical: DesignTokens.Spacing.lg)
}

extension View {
	func selectableBackground(
		isSelected: Bool,
		isHovered: Bool,
		cornerRadius: CGFloat = DesignTokens.CornerRadius.md,
		settings: AppSettings
	) -> some View {
		background(
			RoundedRectangle(cornerRadius: cornerRadius)
				.fill(
					isSelected
						? settings.accentColorUI.opacity(0.2)
						: (isHovered ? settings.searchBarColorUI : Color.clear)
				)
		)
	}

	func appText(
		_ style: TextStyle = .body,
		color: KeyPath<AppSettings, Color> = \.textColorUI,
		settings: AppSettings
	) -> some View {
		self
			.font(Font(settings.uiFont.withSize(style.size)))
			.foregroundColor(settings[keyPath: color])
	}

	func appCard(
		settings: AppSettings,
		padding: Spacing = .medium,
		cornerRadius: CGFloat = DesignTokens.CornerRadius.md,
		hoverState: Bool = false
	) -> some View {
		self
			.padding(.horizontal, padding.horizontal)
			.padding(.vertical, padding.vertical)
			.background(hoverState ? settings.searchBarColorUI30 : settings.searchBarColorUI)
			.cornerRadius(cornerRadius)
	}
}
