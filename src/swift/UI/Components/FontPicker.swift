import AppKit
import SwiftUI

struct FontPicker: View {
	@Binding var selectedFont: String
	@ObservedObject var settings: AppSettings
	@State private var isExpanded = false
	@State private var searchText = ""
	@State private var buttonFrame: CGRect = .zero

	private var allFonts: [FontOption] {
		FontCache.shared.getAllFonts()
	}

	private var filteredFonts: [FontOption] {
		searchText.isEmpty ? allFonts : allFonts.filter {
			$0.display.localizedCaseInsensitiveContains(searchText)
		}
	}

	private var selectedFontOption: FontOption {
		allFonts.first { $0.name == selectedFont } ?? FontOption(name: "", display: "System", category: "System")
	}

	private var groupedFonts: [(String, [FontOption])] {
		Dictionary(grouping: filteredFonts, by: \.category)
			.sorted { $0.key < $1.key }
			.map { ($0.key, $0.value.sorted { $0.display < $1.display }) }
	}

	var body: some View {
		GeometryReader { _ in
			VStack(spacing: 0) {
				toggleButton
					.background(
						GeometryReader { geo in
							Color.clear.preference(
								key: FramePreferenceKey.self,
								value: geo.frame(in: .global)
							)
						}
					)
					.onPreferenceChange(FramePreferenceKey.self) { frame in
						buttonFrame = frame
					}
			}
			.overlay(alignment: .topLeading) {
				if isExpanded {
					dropdownContent
						.position(
							x: buttonFrame.minX + (buttonFrame.width / 2),
							y: buttonFrame.maxY + (DesignTokens.Dropdown.maxHeight / 2) + DesignTokens.Spacing.xs
						)
						.transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
				}
			}
		}
		.frame(height: 28)
		.animation(.easeOut(duration: 0.15), value: isExpanded)
	}

	private var toggleButton: some View {
		SwiftUI.Button {
			isExpanded.toggle()
			if isExpanded { searchText = "" }
		} label: {
			HStack {
				Text(selectedFontOption.display)
					.styled(fontSize: DesignTokens.Typography.body, settings: settings)
					.foregroundColor(settings.textColorUI)
				Spacer()
				Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
					.font(.system(size: 10))
					.foregroundColor(settings.secondaryTextColorUI)
			}
			.padding(.horizontal, DesignTokens.Spacing.md)
			.padding(.vertical, DesignTokens.Spacing.xs)
			.background(settings.backgroundColorUI)
			.cornerRadius(DesignTokens.CornerRadius.sm)
			.overlay(
				RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
					.stroke(settings.secondaryTextColorUI.opacity(DesignTokens.Opacity.border), lineWidth: 1)
			)
		}
		.buttonStyle(PlainButtonStyle())
	}

	private var dropdownContent: some View {
		VStack(spacing: DesignTokens.Spacing.xs) {
			searchField
			fontList
		}
		.padding(DesignTokens.Spacing.sm)
		.frame(width: buttonFrame.width, height: DesignTokens.Dropdown.maxHeight)
		.background(settings.backgroundColorUI)
		.cornerRadius(DesignTokens.CornerRadius.md)
		.overlay(
			RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
				.stroke(settings.secondaryTextColorUI.opacity(DesignTokens.Opacity.border), lineWidth: 1)
		)
		.shadow(color: .black.opacity(0.2), radius: 8, y: 2)
	}

	private var searchField: some View {
		HStack(spacing: DesignTokens.Spacing.xs) {
			Image(systemName: "magnifyingglass")
				.font(.system(size: DesignTokens.Typography.small))
				.foregroundColor(settings.secondaryTextColorUI)

			TextField("Search fonts...", text: $searchText)
				.textFieldStyle(PlainTextFieldStyle())
				.styled(fontSize: DesignTokens.Typography.body, settings: settings)
				.foregroundColor(settings.textColorUI)
		}
		.padding(.horizontal, DesignTokens.Spacing.md)
		.padding(.vertical, DesignTokens.Spacing.xs)
		.background(settings.searchBarColorUI)
		.cornerRadius(DesignTokens.CornerRadius.sm)
	}

	private var fontList: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
				ForEach(groupedFonts, id: \.0) { category, fonts in
					VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
						if !searchText.isEmpty || groupedFonts.count > 1 {
							Text(category.uppercased())
								.font(.system(size: DesignTokens.Typography.small - 1))
								.foregroundColor(settings.secondaryTextColorUI
									.opacity(DesignTokens.Opacity.categoryText))
								.padding(.horizontal, DesignTokens.Spacing.sm)
								.padding(.top, category == groupedFonts.first?.0 ? 0 : DesignTokens.Spacing.xs)
						}

						ForEach(fonts, id: \.name) { font in
							FontRow(
								font: font,
								isSelected: selectedFont == font.name,
								settings: settings,
								onSelect: {
									selectedFont = font.name
									isExpanded = false
								}
							)
						}
					}
				}
			}
		}
	}
}

struct FontRow: View {
	let font: FontOption
	let isSelected: Bool
	let settings: AppSettings
	let onSelect: () -> Void
	@State private var isHovered = false

	var body: some View {
		SwiftUI.Button(action: onSelect) {
			HStack {
				Text(font.display)
					.styled(fontSize: DesignTokens.Typography.body, settings: settings)
					.foregroundColor(settings.textColorUI)
				Spacer()
				if isSelected {
					Image(systemName: "checkmark")
						.font(.system(size: DesignTokens.Typography.small))
						.foregroundColor(settings.accentColorUI)
				}
			}
			.padding(.horizontal, DesignTokens.Spacing.sm)
			.padding(.vertical, DesignTokens.Spacing.xs)
			.background(
				isSelected
					? settings.accentColorUI.opacity(DesignTokens.Opacity.selected)
					: (isHovered ? settings.searchBarColorUI.opacity(DesignTokens.Opacity.hover) : .clear)
			)
			.cornerRadius(DesignTokens.CornerRadius.sm)
		}
		.buttonStyle(PlainButtonStyle())
		.onHover { isHovered = $0 }
	}
}

struct FramePreferenceKey: PreferenceKey {
	static var defaultValue: CGRect = .zero
	static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
		value = nextValue()
	}
}

struct FontOption: Hashable {
	let name: String
	let display: String
	let category: String
}

class FontCache {
	static let shared = FontCache()
	private var cachedFonts: [FontOption]?

	private init() {}

	func getAllFonts() -> [FontOption] {
		if let cached = cachedFonts {
			return cached
		}

		var fonts: [FontOption] = [FontOption(name: "", display: "System", category: "System")]

		let monospaceFonts: Set<String> = [
			"Monaco", "Menlo", "Courier", "Courier New", "SF Mono", "Andale Mono", "Consolas",
			"DejaVu Sans Mono", "Droid Sans Mono", "Fira Code", "Fira Mono", "Hack",
			"IBM Plex Mono", "Inconsolata", "JetBrains Mono", "Liberation Mono",
			"Lucida Console", "Noto Mono", "PT Mono", "Roboto Mono", "Source Code Pro",
			"Ubuntu Mono", "Cascadia Code", "Cascadia Mono"
		]

		for family in NSFontManager.shared.availableFontFamilies {
			if monospaceFonts.contains(family) {
				fonts.append(FontOption(name: family, display: family, category: "Monospace"))
			} else if let font = NSFont(name: family, size: 12), font.isFixedPitch {
				fonts.append(FontOption(name: family, display: family, category: "Monospace"))
			}
		}

		fonts.sort {
			$0.category == $1.category ? $0.display < $1.display : $0.category < $1.category
		}

		cachedFonts = fonts
		return fonts
	}
}
