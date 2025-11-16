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
		settings.theme.accentColorUI
	}

	private var textColor: Color {
		settings.theme.textColorUI
	}

	private var searchBarColor: Color {
		settings.theme.searchBarColorUI
	}

	var body: some View {
		if result.category == "Calculator" {
			calculatorRow
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
		if let customIcon = result.icon {
			icon = customIcon
			return
		}

		let noIconCategories = ["Clipboard", "Action", "Command", "Calculator"]
		guard !noIconCategories.contains(result.category), let path = result.path else { return }

		if let cachedIcon = IconCache.shared.get(path) {
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

			IconCache.shared.set(path, icon: resizedIcon)

			DispatchQueue.main.async {
				icon = resizedIcon
			}
		}
	}
}
