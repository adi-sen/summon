import AppKit
import Foundation

enum WebIconDownloader {
	private static let iconCache = NSCache<NSString, NSImage>()

	private static let fallbackColors: [NSColor] = [
		NSColor(red: 0.26, green: 0.52, blue: 0.96, alpha: 1.0), // Blue
		NSColor(red: 0.95, green: 0.26, blue: 0.21, alpha: 1.0), // Red
		NSColor(red: 0.30, green: 0.69, blue: 0.31, alpha: 1.0), // Green
		NSColor(red: 0.61, green: 0.15, blue: 0.69, alpha: 1.0), // Purple
		NSColor(red: 0.96, green: 0.50, blue: 0.09, alpha: 1.0), // Orange
		NSColor(red: 0.00, green: 0.74, blue: 0.83, alpha: 1.0), // Cyan
		NSColor(red: 0.91, green: 0.12, blue: 0.39, alpha: 1.0), // Pink
		NSColor(red: 0.40, green: 0.23, blue: 0.72, alpha: 1.0) // Indigo
	]

	static func getIcon(for name: String, size: NSSize, completion: @escaping (NSImage?) -> Void) {
		let cacheKey = "\(name)-\(Int(size.width))x\(Int(size.height))" as NSString
		if let cached = iconCache.object(forKey: cacheKey) {
			completion(cached)
			return
		}

		if let icon = loadIcon(name: name, size: size) {
			iconCache.setObject(icon, forKey: cacheKey)
			completion(icon)
			return
		}

		let fallbackIcon = generateFallbackIcon(name: name, size: size)
		if let fallbackIcon {
			iconCache.setObject(fallbackIcon, forKey: cacheKey)
		}
		completion(fallbackIcon)
	}

	private static func loadIcon(name: String, size: NSSize) -> NSImage? {
		if let userIconPath = StoragePathManager.shared.getWebIconPath(forName: name),
		   let image = NSImage(contentsOfFile: userIconPath)
		{
			return compressAndResize(image: image, to: size)
		}

		if let bundledIcon = loadBundledIcon(name: name, size: size) {
			return bundledIcon
		}

		return nil
	}

	private static func loadBundledIcon(name: String, size: NSSize) -> NSImage? {
		guard let resourcePath = Bundle.main.resourcePath else { return nil }
		let iconsDir = "\(resourcePath)/web-icons"

		let formats = ["png", "jpg", "jpeg", "webp", "heic", "gif", "tiff", "bmp", "ico"]
		for format in formats {
			let iconPath = "\(iconsDir)/\(name).\(format)"
			if let image = NSImage(contentsOfFile: iconPath) {
				return compressAndResize(image: image, to: size)
			}
		}

		return nil
	}

	private static func compressAndResize(image: NSImage, to size: NSSize) -> NSImage? {
		let newImage = NSImage(size: size)
		newImage.lockFocus()

		NSGraphicsContext.current?.imageInterpolation = .high
		image.draw(
			in: NSRect(origin: .zero, size: size),
			from: NSRect(origin: .zero, size: image.size),
			operation: .copy,
			fraction: 1.0
		)

		newImage.unlockFocus()

		guard let tiffData = newImage.tiffRepresentation,
		      let bitmap = NSBitmapImageRep(data: tiffData),
		      let compressedData = bitmap.representation(
		      	using: .jpeg,
		      	properties: [.compressionFactor: 0.8]
		      )
		else {
			return newImage
		}

		return NSImage(data: compressedData) ?? newImage
	}

	private static func generateFallbackIcon(name: String, size: NSSize) -> NSImage? {
		let colorIndex = abs(name.hashValue) % fallbackColors.count
		let color = fallbackColors[colorIndex]

		let image = NSImage(size: size)
		image.lockFocus()

		let rect = NSRect(origin: .zero, size: size)
		let circlePath = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))

		color.setFill()
		circlePath.fill()

		let letter = name.prefix(1).uppercased()
		let fontSize = size.height * 0.5
		let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
		let attributes: [NSAttributedString.Key: Any] = [
			.font: font,
			.foregroundColor: NSColor.white
		]

		let letterSize = letter.size(withAttributes: attributes)
		let letterRect = NSRect(
			x: (size.width - letterSize.width) / 2,
			y: (size.height - letterSize.height) / 2,
			width: letterSize.width,
			height: letterSize.height
		)

		letter.draw(in: letterRect, withAttributes: attributes)

		image.unlockFocus()
		return image
	}

	static func clearCache() {
		iconCache.removeAllObjects()
	}

	static func deleteIcon(forName name: String) {
		let sizes = [28, 32, 48, 64] // Common icon sizes
		for size in sizes {
			let cacheKey = "\(name)-\(size)x\(size)" as NSString
			iconCache.removeObject(forKey: cacheKey)
		}

		if let iconPath = StoragePathManager.shared.getWebIconPath(forName: name) {
			try? FileManager.default.removeItem(atPath: iconPath)
		}
	}

	static func getIconsDirectory() -> String {
		StoragePathManager.shared.getWebIconsDir()
	}
}
