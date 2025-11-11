import AppKit
import SwiftUI

enum ActionIconGenerator {
	static func loadIcon(iconName: String, title: String, url: String?) -> NSImage? {
		if iconName.hasPrefix("/") || iconName.hasPrefix("~"),
		   let image = NSImage(contentsOfFile: NSString(string: iconName).expandingTildeInPath as String)
		{
			return image
		}

		if iconName.hasPrefix("web:") {
			let path = "\(NSHomeDirectory())/Library/Application Support/Summon/WebIcons/\(String(iconName.dropFirst(4))).png"
			if let image = NSImage(contentsOfFile: path) {
				return image
			}
		}

		return generateIcon(for: title, iconName: iconName, url: url)
	}

	static func generateIcon(for actionName: String, iconName: String, url: String?) -> NSImage {
		if let url, let icon = iconForDomain(url: url, actionName: actionName) {
			return icon
		}

		return generateSymbolIcon(symbolName: iconName, actionName: actionName)
	}

	private static func iconForDomain(url: String, actionName: String) -> NSImage? {
		guard let urlComponents = URLComponents(string: url),
		      let host = urlComponents.host?.lowercased()
		else {
			return nil
		}

		let domainColors: [String: NSColor] = [
			"github.com": NSColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0),
			"google.com": NSColor(red: 0.26, green: 0.52, blue: 0.96, alpha: 1.0),
			"youtube.com": NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
			"duckduckgo.com": NSColor(red: 0.87, green: 0.33, blue: 0.13, alpha: 1.0),
			"twitter.com": NSColor(red: 0.11, green: 0.63, blue: 0.95, alpha: 1.0),
			"x.com": NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
			"reddit.com": NSColor(red: 1.0, green: 0.27, blue: 0.0, alpha: 1.0),
			"stackoverflow.com": NSColor(red: 0.94, green: 0.48, blue: 0.20, alpha: 1.0),
			"wikipedia.org": NSColor(white: 0.95, alpha: 1.0),
			"amazon.com": NSColor(red: 1.0, green: 0.60, blue: 0.0, alpha: 1.0),
			"linkedin.com": NSColor(red: 0.0, green: 0.47, blue: 0.71, alpha: 1.0)
		]

		let domainSymbols: [String: String] = [
			"github.com": "chevron.left.forwardslash.chevron.right",
			"google.com": "globe.americas.fill",
			"youtube.com": "play.rectangle.fill",
			"duckduckgo.com": "shield.fill",
			"twitter.com": "bird.fill",
			"x.com": "xmark",
			"reddit.com": "bubble.left.and.bubble.right.fill",
			"stackoverflow.com": "bubble.left.and.bubble.right.fill",
			"wikipedia.org": "book.closed.fill",
			"amazon.com": "cart.fill",
			"linkedin.com": "briefcase.fill"
		]

		for (domain, color) in domainColors where host.hasSuffix(domain) {
			let symbol = domainSymbols[domain] ?? "globe"
			return createIconWithSymbol(
				symbol: symbol,
				backgroundColor: color,
				foregroundColor: domain == "wikipedia.org" || domain == "github.com"
					? .black : .white
			)
		}

		return nil
	}

	private static func generateSymbolIcon(symbolName: String, actionName: String) -> NSImage {
		let color = colorForName(actionName)

		return createIconWithSymbol(
			symbol: symbolName.isEmpty ? "globe" : symbolName,
			backgroundColor: color,
			foregroundColor: .white
		)
	}

	private static func createIconWithSymbol(
		symbol: String,
		backgroundColor: NSColor,
		foregroundColor: NSColor
	) -> NSImage {
		let size = NSSize(width: 28, height: 28)
		let image = NSImage(size: size)

		image.lockFocus()

		let rect = NSRect(origin: .zero, size: size)
		let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
		backgroundColor.setFill()
		path.fill()

		let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
		if let symbolImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
			.withSymbolConfiguration(config)
		{
			let symbolRect = NSRect(
				x: (size.width - 16) / 2,
				y: (size.height - 16) / 2,
				width: 16,
				height: 16
			)

			symbolImage.lockFocus()
			foregroundColor.setFill()
			symbolRect.fill(using: .sourceAtop)
			symbolImage.unlockFocus()

			symbolImage.draw(
				in: symbolRect,
				from: NSRect(origin: .zero, size: symbolImage.size),
				operation: .sourceOver,
				fraction: 1.0
			)
		}

		image.unlockFocus()

		return image
	}

	private static func colorForName(_ name: String) -> NSColor {
		let hash = abs(name.hashValue)
		let hue = Double(hash % 360) / 360.0

		return NSColor(hue: hue, saturation: 0.65, brightness: 0.75, alpha: 1.0)
	}
}
