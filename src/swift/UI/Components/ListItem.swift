import SwiftUI

struct ListItem<TrailingContent: View>: View {
	let icon: ListItemIcon
	let title: String
	let subtitle: String?
	let isSelected: Bool
	let isHovered: Binding<Bool>?
	let trailingContent: TrailingContent
	let action: (() -> Void)?
	@EnvironmentObject var settings: AppSettings

	enum ListItemIcon {
		case sfSymbol(String, Color? = nil)
		case image(NSImage)
		case none

		var isSmall: Bool {
			false
		}
	}

	init(
		icon: ListItemIcon = .none,
		title: String,
		subtitle: String? = nil,
		isSelected: Bool = false,
		isHovered: Binding<Bool>? = nil,
		action: (() -> Void)? = nil,
		@ViewBuilder trailingContent: () -> TrailingContent
	) {
		self.icon = icon
		self.title = title
		self.subtitle = subtitle
		self.isSelected = isSelected
		self.isHovered = isHovered
		self.trailingContent = trailingContent()
		self.action = action
	}

	var body: some View {
		SwiftUI.Button(action: { action?() }) {
			HStack(spacing: DesignTokens.Spacing.lg) {
				iconView
					.frame(width: DesignTokens.Layout.iconSize, height: DesignTokens.Layout.iconSize)

				VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
					Text(title)
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
						.foregroundColor(settings.textColorUI)
						.lineLimit(1)

					if let subtitle {
						Text(subtitle)
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
							.foregroundColor(settings.secondaryTextColorUI)
							.lineLimit(1)
					}
				}

				Spacer()

				trailingContent
			}
			.padding(.horizontal, DesignTokens.Spacing.lg)
			.padding(.vertical, DesignTokens.Spacing.md)
			.background(backgroundView)
		}
		.buttonStyle(PlainButtonStyle())
		.onHover { hovering in
			isHovered?.wrappedValue = hovering
		}
	}

	@ViewBuilder
	private var iconView: some View {
		switch icon {
		case .sfSymbol(let name, let color):
			Image(systemName: name)
				.font(Font(settings.uiFont.withSize(16)))
				.foregroundColor(color ?? settings.accentColorUI)
		case .image(let image):
			Image(nsImage: image)
				.resizable()
		case .none:
			EmptyView()
		}
	}

	@ViewBuilder
	private var backgroundView: some View {
		RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
			.fill(
				isSelected
					? settings.accentColorUI.opacity(0.2)
					: (isHovered?.wrappedValue == true ? settings.searchBarColorUI : Color.clear)
			)
	}
}

/// Convenience initializer with no trailing content
extension ListItem where TrailingContent == EmptyView {
	init(
		icon: ListItemIcon = .none,
		title: String,
		subtitle: String? = nil,
		isSelected: Bool = false,
		isHovered: Binding<Bool>? = nil,
		action: (() -> Void)? = nil
	) {
		self.icon = icon
		self.title = title
		self.subtitle = subtitle
		self.isSelected = isSelected
		self.isHovered = isHovered
		self.trailingContent = EmptyView()
		self.action = action
	}
}

/// Compact list item for simple cases (like folder rows)
struct CompactListItem: View {
	let icon: String
	let iconColor: Color
	let title: String
	let isSelected: Bool
	let onSelect: () -> Void
	let onSecondaryAction: (() -> Void)?
	@EnvironmentObject var settings: AppSettings
	@State private var isHovered = false

	init(
		icon: String,
		iconColor: Color = .blue,
		title: String,
		isSelected: Bool = false,
		onSelect: @escaping () -> Void,
		onSecondaryAction: (() -> Void)? = nil
	) {
		self.icon = icon
		self.iconColor = iconColor
		self.title = title
		self.isSelected = isSelected
		self.onSelect = onSelect
		self.onSecondaryAction = onSecondaryAction
	}

	var body: some View {
		SwiftUI.Button(action: onSelect) {
			HStack(spacing: DesignTokens.Spacing.lg) {
				Image(systemName: icon)
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.large)))
					.foregroundColor(iconColor.opacity(0.8))

				Text(title)
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
					.foregroundColor(settings.textColorUI)

				Spacer()

				if let onSecondaryAction {
					SwiftUI.Button(action: onSecondaryAction) {
						Image(systemName: "chevron.right")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
							.foregroundColor(settings.secondaryTextColorUI)
					}
					.buttonStyle(PlainButtonStyle())
				}
			}
			.padding(.horizontal, DesignTokens.Spacing.lg)
			.padding(.vertical, DesignTokens.Spacing.md)
			.background(
				RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
					.fill(
						isSelected
							? settings.accentColorUI.opacity(0.2)
							: isHovered ? settings.searchBarColorUI : Color.clear
					)
			)
		}
		.buttonStyle(PlainButtonStyle())
		.onHover { hovering in
			isHovered = hovering
		}
	}
}
