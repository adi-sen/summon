import SwiftUI

struct ResultRow: View {
	let result: CategoryResult
	let isSelected: Bool
	let hideCategory: Bool
	let quickSelectNumber: Int?
	@State private var icon: NSImage?
	@EnvironmentObject var settings: AppSettings

	private var isSmallIcon: Bool {
		result.category == "Clipboard"
	}

	private var accentColor: Color {
		settings.accentColorUI
	}

	private var textColor: Color {
		settings.textColorUI
	}

	private var searchBarColor: Color {
		settings.searchBarColorUI
	}

	var body: some View {
		if result.category == "Calculator" {
			calculatorRow
		} else if result.category == "Dictionary" {
			dictionaryRow
		} else if result.category == "DictionaryNotFound" {
			dictionaryNotFoundRow
		} else {
			standardRow
		}
	}

	private var calculatorRow: some View {
		let fontSize = settings.compactMode ? DesignTokens.Typography.large : DesignTokens.Typography.xlarge
		let font = Font(settings.uiFont.withSize(fontSize))
		let verticalPadding = settings.compactMode ? DesignTokens.Spacing.sm : DesignTokens.Spacing.lg

		return HStack(spacing: 0) {
			if let subtitle = resultSubtitle {
				Text(subtitle)
					.font(font)
					.foregroundColor(textColor.opacity(0.8))
					.lineLimit(1)
					.frame(maxWidth: .infinity)
					.multilineTextAlignment(.center)
			}

			Divider()
				.frame(width: 1)
				.background(accentColor.opacity(0.2))

			Text(result.name)
				.font(font)
				.foregroundColor(isSelected ? .white : accentColor)
				.fontWeight(.semibold)
				.lineLimit(1)
				.frame(maxWidth: .infinity)
				.multilineTextAlignment(.center)
		}
		.padding(.horizontal, DesignTokens.Spacing.xl)
		.padding(.vertical, verticalPadding)
		.frame(maxWidth: .infinity)
		.background(
			RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
				.fill(isSelected ? accentColor.opacity(0.15) : searchBarColor)
		)
		.overlay(
			RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
				.stroke(isSelected ? accentColor.opacity(0.4) : Color.clear, lineWidth: 2)
		)
		.padding(.horizontal, DesignTokens.Spacing.sm)
		.padding(.vertical, DesignTokens.Spacing.xxs)
	}

	@ViewBuilder
	private var dictionaryRow: some View {
		if settings.compactMode {
			compactDictionaryRow
		} else {
			expandedDictionaryRow
		}
	}

	private var compactDictionaryRow: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(alignment: .firstTextBaseline, spacing: 6) {
				Text(result.name)
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.xlarge)).weight(.bold))
					.foregroundColor(textColor)
					.lineLimit(1)

				if let pronunciation = extractPronunciation(result.path) {
					Text("/\(pronunciation)/")
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(textColor.opacity(0.45))
						.lineLimit(1)
				}
			}

			if let definition = result.path {
				let structured = parseDefinitionStructure(definition)
				ForEach(Array(structured.prefix(1)), id: \.id) { section in
					dictionarySection(section, compact: true)
				}
			}
		}
		.padding(.horizontal, DesignTokens.Spacing.md)
		.padding(.vertical, 8)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color.clear)
		.padding(.horizontal, DesignTokens.Spacing.xs)
		.padding(.vertical, 0)
	}

	private var expandedDictionaryRow: some View {
		VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
			HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
				Text(result.name)
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.xlarge + 4)).weight(.bold))
					.foregroundColor(textColor)
					.lineLimit(1)

				if let pronunciation = extractPronunciation(result.path) {
					Text("/" + pronunciation + "/")
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.large)))
						.foregroundColor(textColor.opacity(0.5))
						.lineLimit(1)
				}
			}

			if let definition = result.path {
				let structured = parseDefinitionStructure(definition)
				ForEach(structured, id: \.id) { section in
					dictionarySection(section, compact: false)
				}
			}
		}
		.padding(.horizontal, DesignTokens.Spacing.lg)
		.padding(.vertical, DesignTokens.Spacing.md)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color.clear)
		.padding(.horizontal, DesignTokens.Spacing.xs)
		.padding(.vertical, DesignTokens.Spacing.xxs)
	}

	struct DefinitionSection: Identifiable {
		let id = UUID()
		let partOfSpeech: String?
		let definitions: [String]
	}

	private func extractPronunciation(_ definition: String?) -> String? {
		guard let def = definition else { return nil }
		let pattern = "\\|([^|]+)\\|"
		if let regex = try? NSRegularExpression(pattern: pattern),
		   let match = regex.firstMatch(in: def, range: NSRange(def.startIndex..., in: def)),
		   let range = Range(match.range(at: 1), in: def) {
			return String(def[range])
		}
		return nil
	}

	private func parseDefinitionStructure(_ definition: String) -> [DefinitionSection] {
		// Single-pass cleaning with combined regex
		guard let firstPipe = definition.firstIndex(of: "|") else {
			return []
		}

		var text = String(definition[definition.index(after: firstPipe)...])

		// Combined regex for all removals in one pass
		let cleanPattern = #"\|[^|]+\||\((?:also|plural)[^)]*\)|\[no object\]|\bmainly\s+\w+\s+\w+\b"#
		text = text.replacingOccurrences(of: cleanPattern, with: "", options: .regularExpression)

		// Early termination at ORIGIN
		if let originIdx = text.range(of: "ORIGIN", options: .caseInsensitive)?.lowerBound {
			text = String(text[..<originIdx])
		}

		// Pre-split by bullets once
		let bulletParts = text.split(separator: "•", omittingEmptySubsequences: false)

		let posPatterns = ["exclamation", "noun", "verb", "adjective", "adverb", "preposition", "conjunction"]
		var sections: [DefinitionSection] = []
		var currentPos: String?
		var currentDefs: [String] = []

		for part in bulletParts {
			let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmed.isEmpty else { continue }

			// Check if this part contains a new part of speech
			var foundNewPos = false
			for pos in posPatterns where trimmed.lowercased().contains(pos) {
				// Save previous section
				if let prevPos = currentPos, !currentDefs.isEmpty {
					sections.append(DefinitionSection(partOfSpeech: prevPos, definitions: currentDefs))
				}
				currentPos = pos
				currentDefs = []
				foundNewPos = true

				// Extract definition from this part (after POS marker)
				if let posRange = trimmed.range(of: pos, options: .caseInsensitive) {
					let afterPos = trimmed[posRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
					if let def = extractSingleDefinition(String(afterPos)) {
						currentDefs.append(def)
					}
				}
				break
			}

			// Regular definition (no new POS)
			if !foundNewPos, let def = extractSingleDefinition(trimmed) {
				currentDefs.append(def)
			}
		}

		// Append last section
		if let pos = currentPos, !currentDefs.isEmpty {
			sections.append(DefinitionSection(partOfSpeech: pos, definitions: currentDefs))
		}

		return sections
	}

	private func extractSingleDefinition(_ text: String) -> String? {
		var cleaned = text

		// Remove leading POS keywords
		for pos in ["exclamation", "noun", "verb", "adjective", "adverb"] {
			if cleaned.lowercased().hasPrefix(pos) {
				cleaned = String(cleaned.dropFirst(pos.count)).trimmingCharacters(in: .whitespaces)
				break
			}
		}

		// Extract before colon (examples)
		if let colonIdx = cleaned.firstIndex(of: ":") {
			cleaned = String(cleaned[..<colonIdx])
		}

		cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

		return cleaned.count > 5 && !cleaned.hasPrefix("\"") ? cleaned : nil
	}

	@ViewBuilder
	private func dictionarySection(_ section: DefinitionSection, compact: Bool) -> some View {
		VStack(alignment: .leading, spacing: 3) {
			if let pos = section.partOfSpeech {
				HStack(spacing: 4) {
					Circle()
						.fill(textColor.opacity(0.3))
						.frame(width: 3, height: 3)
					Text(pos)
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small - 1)).italic())
						.foregroundColor(textColor.opacity(0.55))
						.tracking(0.3)
				}
			}

			ForEach(Array(section.definitions.enumerated()), id: \.offset) { index, def in
				if compact && index >= 3 { EmptyView() } else {
					HStack(alignment: .top, spacing: 8) {
						if section.definitions.count > 1 {
							Text("\(index + 1)")
								.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small - 1)).monospacedDigit())
								.foregroundColor(accentColor.opacity(0.6))
								.frame(width: 16, alignment: .trailing)
						}

						Text(def)
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
							.foregroundColor(textColor.opacity(0.88))
							.fixedSize(horizontal: false, vertical: true)
					}
				}
			}
		}
	}

	private var dictionaryNotFoundRow: some View {
		VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
			Text(result.name)
				.font(Font(settings.uiFont.withSize(settings.compactMode ? DesignTokens.Typography.large : DesignTokens.Typography.xlarge)).weight(.semibold))
				.foregroundColor(textColor)
				.lineLimit(1)

			if let message = result.path {
				Text(message)
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
					.foregroundColor(textColor.opacity(0.6))
					.lineLimit(1)
			}
		}
		.padding(.horizontal, DesignTokens.Spacing.md)
		.padding(.vertical, DesignTokens.Spacing.md)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color.clear)
		.padding(.horizontal, DesignTokens.Spacing.xs)
		.padding(.vertical, DesignTokens.Spacing.xxs)
	}

	private var standardRow: some View {
		HStack(spacing: DesignTokens.Spacing.md + 2) {
			ZStack(alignment: .topTrailing) {
				if let icon {
					Image(nsImage: icon)
						.resizable()
						.frame(width: iconSize, height: iconSize)
				} else {
					Image(systemName: iconName)
						.font(Font(settings.uiFont.withSize(symbolFontSize)))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(iconColor)
				}

				if result.category == "Pinned" {
					Image(systemName: "pin.fill")
						.font(Font(settings.uiFont.withSize(8)))
						.foregroundColor(accentColor)
						.offset(x: 4, y: -4)
				}
			}
			.frame(width: iconSize, height: iconSize)

			VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
				Text(result.name)
					.font(settings.resultNameFont)
					.foregroundColor(.primary)
					.lineLimit(1)

				if let subtitle = resultSubtitle {
					Text(subtitle)
						.font(settings.resultCategoryFont)
						.foregroundColor(.secondary.opacity(0.6))
						.lineLimit(1)
				}
			}

			Spacer()

			if let number = quickSelectNumber, settings.showQuickSelect {
				Text(settings.quickSelectModifier.displaySymbol + String(number))
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
					.foregroundColor(.secondary.opacity(0.5))
			}
		}
		.padding(.horizontal, DesignTokens.Spacing.md + 2)
		.padding(.vertical, DesignTokens.Spacing.sm)
		.background(isSelected ? accentColor.opacity(0.5) : Color.clear)
		.cornerRadius(DesignTokens.CornerRadius.md)
		.padding(.horizontal, DesignTokens.Spacing.xs)
		.padding(.vertical, 0)
		.onAppear {
			loadIcon()
		}
	}

	private var iconSize: CGFloat { isSmallIcon ? 16 : DesignTokens.Layout.iconSize }
	private var symbolFontSize: CGFloat { isSmallIcon ? DesignTokens.Typography.body : 20 }

	private var iconName: String {
		if result.id.hasPrefix("cmd_") {
			return ["cmd_settings": "gearshape.fill", "cmd_clipboard": "doc.on.clipboard.fill"][result.id] ?? "command.circle.fill"
		}

		switch result.category {
		case "Calculator": return "equal.circle.fill"
		case "Dictionary": return "book.closed.fill"
		case "Action": return "globe"
		case "Clipboard":
			if let entry = result.clipboardEntry {
				switch entry.type {
				case .image: return "photo.fill"
				case .text: return entry.content.hasPrefix("http") ? "link" : "textformat"
				case .unknown: return "doc.on.clipboard"
				}
			} else { return "doc.on.clipboard" }
		default: return "app"
		}
	}

	private var iconColor: Color {
		if result.id.hasPrefix("cmd_") {
			return accentColor.opacity(0.8)
		}

		switch result.category {
		case "Calculator": return accentColor
		case "Dictionary": return accentColor
		default: return Color.secondary.opacity(0.8)
		}
	}

	private var resultSubtitle: String? {
		switch result.category {
		case "Calculator": result.path
		case "Clipboard": result.clipboardEntry?.timeAgo
		default: nil
		}
	}

	private func loadIcon() {
		guard icon == nil else { return }

		if let customIcon = result.icon {
			icon = customIcon
			return
		}

		let noIconCategories = ["Clipboard", "Action", "Command", "Calculator", "Dictionary"]
		guard !noIconCategories.contains(result.category), let path = result.path else { return }

		if let cachedIcon = ImageCache.icon.get(path) {
			icon = cachedIcon
			return
		}

		DispatchQueue.global(qos: .userInitiated).async {
			let targetSize = NSSize(width: DesignTokens.Layout.iconSize, height: DesignTokens.Layout.iconSize)
			let resizedIcon = autoreleasepool {
				let loadedIcon = NSWorkspace.shared.icon(forFile: path)
				let resized = NSImage(size: targetSize)
				resized.lockFocus()
				loadedIcon.draw(
					in: NSRect(origin: .zero, size: targetSize),
					from: NSRect(origin: .zero, size: loadedIcon.size),
					operation: .copy,
					fraction: 1.0
				)
				resized.unlockFocus()
				return resized
			}

			ImageCache.icon.set(path, image: resizedIcon)

			DispatchQueue.main.async {
				icon = resizedIcon
			}
		}
	}
}
