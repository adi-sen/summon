import SwiftUI

struct RadioGroup<T: Hashable>: View {
	let items: [T]
	@Binding var selection: T
	let label: (T) -> String
	let columns: Int
	@ObservedObject var settings: AppSettings

	init(
		items: [T],
		selection: Binding<T>,
		label: @escaping (T) -> String,
		columns: Int = 1,
		settings: AppSettings = .shared
	) {
		self.items = items
		self._selection = selection
		self.label = label
		self.columns = columns
		self.settings = settings
	}

	var body: some View {
		LazyVGrid(
			columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Spacing.md), count: columns),
			alignment: .leading,
			spacing: DesignTokens.Spacing.sm
		) {
			ForEach(items, id: \.self) { item in
				RadioOption(
					label: label(item),
					isSelected: selection == item,
					settings: settings,
					onSelect: { selection = item }
				)
			}
		}
	}
}

struct RadioOption: View {
	let label: String
	let isSelected: Bool
	let settings: AppSettings
	let onSelect: () -> Void
	@State private var isHovered = false

	var body: some View {
		SwiftUI.Button(action: onSelect) {
			HStack(spacing: DesignTokens.Spacing.sm) {
				Image(systemName: isSelected ? "circle.inset.filled" : "circle")
					.font(.system(size: DesignTokens.Typography.body))
					.foregroundColor(isSelected ? settings.accentColorUI : settings.secondaryTextColorUI.opacity(0.5))

				Text(label)
					.styled(fontSize: DesignTokens.Typography.body, settings: settings)
					.foregroundColor(settings.textColorUI)

				Spacer()
			}
			.padding(.horizontal, DesignTokens.Spacing.sm)
			.padding(.vertical, DesignTokens.Spacing.xs)
			.background(
				isSelected
					? settings.accentColorUI.opacity(DesignTokens.Opacity.selected)
					: (isHovered ? settings.searchBarColorUI.opacity(0.25) : .clear)
			)
			.cornerRadius(DesignTokens.CornerRadius.sm)
		}
		.buttonStyle(PlainButtonStyle())
		.onHover { isHovered = $0 }
	}
}
