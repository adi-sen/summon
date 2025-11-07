import SwiftUI

struct ResultRow: View {
	let result: CategoryResult
	let isSelected: Bool
	let hideCategory: Bool
	let quickSelectNumber: Int?
	@State private var icon: NSImage?
	@ObservedObject var settings = AppSettings.shared

	private var isSmallIcon: Bool {
		result.category == "Clipboard" || result.category == "Action"
	}

	private func themeColor(_ color: (Double, Double, Double)) -> Color {
		Color(red: color.0, green: color.1, blue: color.2)
	}

	var body: some View {
		if result.category == "Calculator" {
			calculatorRow
		} else {
			standardRow
		}
	}

	private var calculatorRow: some View {
		let accentColor = themeColor(settings.theme.accentColor)
		let font = Font(settings.uiFont.withSize(24))

		return HStack(spacing: 0) {
			if let subtitle = resultSubtitle {
				Text(subtitle)
					.font(font)
					.foregroundColor(themeColor(settings.theme.textColor).opacity(0.8))
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
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
		.frame(maxWidth: .infinity)
		.background(
			RoundedRectangle(cornerRadius: 8)
				.fill(isSelected ? accentColor.opacity(0.15) : themeColor(settings.theme.searchBarColor))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 8)
				.stroke(isSelected ? accentColor.opacity(0.4) : Color.clear, lineWidth: 2)
		)
		.padding(.horizontal, 6)
		.padding(.vertical, 2)
	}

	private var standardRow: some View {
		HStack(spacing: 10) {
			if let icon {
				Image(nsImage: icon)
					.resizable()
					.frame(width: iconSize, height: iconSize)
			} else {
				Image(systemName: iconName)
					.font(.system(size: symbolFontSize))
					.frame(width: iconSize, height: iconSize)
					.foregroundColor(iconColor)
			}

			VStack(alignment: .leading, spacing: 2) {
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

			if let number = quickSelectNumber {
				Text(settings.quickSelectModifier.displaySymbol + String(number))
					.font(.system(size: 11, design: .monospaced))
					.foregroundColor(.secondary.opacity(0.5))
			}

			if !hideCategory, quickSelectNumber == nil {
				Text(result.category)
					.font(settings.resultCategoryFont)
					.foregroundColor(.secondary.opacity(0.7))
			}
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 6)
		.background(isSelected ? themeColor(settings.theme.accentColor).opacity(0.5) : Color.clear)
		.cornerRadius(6)
		.padding(.horizontal, 4)
		.padding(.vertical, 0)
		.onAppear {
			loadIcon()
		}
	}

	private var iconSize: CGFloat { isSmallIcon ? 16 : 28 }
	private var symbolFontSize: CGFloat { isSmallIcon ? 13 : 20 }

	private var iconName: String {
		switch result.category {
		case "Calculator": "equal.circle.fill"
		case "Command":
			["cmd_settings": "gearshape.fill", "cmd_clipboard": "doc.on.clipboard.fill"][result.id] ?? "command.circle.fill"
		case "Action": "ellipsis.circle.fill"
		case "Clipboard":
			if let entry = result.clipboardEntry {
				switch entry.type {
				case .image: "photo.fill"
				case .text: entry.content.hasPrefix("http") ? "link" : "textformat"
				case .unknown: "doc.on.clipboard"
				}
			} else { "doc.on.clipboard" }
		default: "app"
		}
	}

	private var iconColor: Color {
		let accentColor = themeColor(settings.theme.accentColor)
		switch result.category {
		case "Calculator": return accentColor
		case "Command": return accentColor.opacity(0.8)
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
			autoreleasepool {
				let loadedIcon = NSWorkspace.shared.icon(forFile: path)

				let size = NSSize(width: 28, height: 28)
				let resized = NSImage(size: size)
				resized.lockFocus()
				loadedIcon.draw(
					in: NSRect(origin: .zero, size: size),
					from: NSRect(origin: .zero, size: loadedIcon.size),
					operation: .copy,
					fraction: 1.0
				)
				resized.unlockFocus()

				IconCache.shared.set(path, icon: resized)

				DispatchQueue.main.async {
					icon = resized
				}
			}
		}
	}
}
