import SwiftUI

struct ThemeCard: View {
	let theme: Theme
	let isSelected: Bool
	let settings: AppSettings
	let onSelect: () -> Void
	@State private var isHovered = false

	var body: some View {
		SwiftUI.Button(action: onSelect) {
			VStack(spacing: DesignTokens.Spacing.xs) {
				HStack(spacing: 2) {
					colorBar(theme.backgroundColor)
					colorBar(theme.searchBarColor)
					colorBar(theme.accentColor)
				}
				.frame(height: 32)
				.cornerRadius(DesignTokens.CornerRadius.sm)

				Text(theme.name)
					.styled(fontSize: DesignTokens.Typography.small, settings: settings)
					.foregroundColor(isSelected ? settings.textColorUI : settings.secondaryTextColorUI)

				Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
					.font(.system(size: DesignTokens.Typography.body))
					.foregroundColor(isSelected ? settings.accentColorUI : settings.secondaryTextColorUI.opacity(0.3))
			}
			.padding(DesignTokens.Spacing.md)
			.background(
				isSelected
					? settings.searchBarColorUI.opacity(DesignTokens.Opacity.dropdownBackground)
					: (isHovered ? settings.searchBarColorUI.opacity(DesignTokens.Opacity.hover) : settings.searchBarColorUI.opacity(DesignTokens.Opacity.controlBackground))
			)
			.cornerRadius(DesignTokens.CornerRadius.md)
			.overlay(
				RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
					.stroke(isSelected ? settings.accentColorUI.opacity(0.5) : .clear, lineWidth: 2)
			)
		}
		.buttonStyle(PlainButtonStyle())
		.onHover { isHovered = $0 }
	}

	private func colorBar(_ color: (Double, Double, Double)) -> some View {
		Rectangle()
			.fill(Color(red: color.0, green: color.1, blue: color.2))
			.frame(maxWidth: .infinity)
	}
}

struct ThemeGrid: View {
	@ObservedObject var settings: AppSettings

	init(settings: AppSettings = .shared) {
		self.settings = settings
	}

	var body: some View {
		LazyVGrid(
			columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.md), count: 4),
			spacing: DesignTokens.Spacing.md
		) {
			ForEach(Theme.allCases, id: \.self) { theme in
				ThemeCard(
					theme: theme,
					isSelected: settings.theme == theme,
					settings: settings,
					onSelect: {
						settings.theme = theme
						settings.scheduleSave()
					}
				)
			}
		}
	}
}
