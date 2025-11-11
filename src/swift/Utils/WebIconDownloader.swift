import AppKit
import Foundation

enum WebIconDownloader {
	private static let iconCache = NSCache<NSString, NSImage>()
	private static let webIconsDir = "\(NSHomeDirectory())/Library/Application Support/Summon/WebIcons"

	private static let iconURLs: [String: String] = [
		"google": "https://www.google.com/favicon.ico",
		"duckduckgo": "https://duckduckgo.com/favicon.ico",
		"github": "https://github.com/favicon.ico",
		"stackoverflow": "https://stackoverflow.com/favicon.ico",
		"wikipedia": "https://en.wikipedia.org/favicon.ico",
		"youtube": "https://www.youtube.com/favicon.ico"
	]

	static func getIcon(for name: String, size: NSSize, completion: @escaping (NSImage?) -> Void) {
		let cacheKey = "\(name)-\(Int(size.width))x\(Int(size.height))" as NSString
		if let cached = iconCache.object(forKey: cacheKey) {
			completion(cached)
			return
		}

		let iconPath = "\(webIconsDir)/\(name).png"
		if FileManager.default.fileExists(atPath: iconPath),
		   let image = NSImage(contentsOfFile: iconPath)
		{
			let resized = resizeIcon(image, targetSize: size)
			iconCache.setObject(resized, forKey: cacheKey)
			completion(resized)
			return
		}

		guard let urlString = iconURLs[name],
		      let url = URL(string: urlString)
		else {
			completion(nil)
			return
		}

		DispatchQueue.global(qos: .userInitiated).async {
			downloadAndCacheIcon(url: url, name: name, size: size) { image in
				DispatchQueue.main.async {
					if let image {
						iconCache.setObject(image, forKey: cacheKey)
					}
					completion(image)
				}
			}
		}
	}

	private static func downloadAndCacheIcon(
		url: URL,
		name: String,
		size: NSSize,
		completion: @escaping (NSImage?) -> Void
	) {
		guard let data = try? Data(contentsOf: url),
		      let image = NSImage(data: data)
		else {
			completion(nil)
			return
		}

		try? FileManager.default.createDirectory(
			atPath: webIconsDir,
			withIntermediateDirectories: true,
			attributes: nil
		)

		let iconPath = "\(webIconsDir)/\(name).png"
		if let tiffData = image.tiffRepresentation,
		   let bitmap = NSBitmapImageRep(data: tiffData),
		   let pngData = bitmap.representation(using: .png, properties: [:])
		{
			try? pngData.write(to: URL(fileURLWithPath: iconPath))
		}

		let resized = resizeIcon(image, targetSize: size)
		completion(resized)
	}

	private static func resizeIcon(_ image: NSImage, targetSize: NSSize) -> NSImage {
		guard
			let imageData = image.tiffRepresentation,
			let bitmap = NSBitmapImageRep(data: imageData)
		else {
			return image
		}

		let sourceSize = NSSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
		let widthRatio = targetSize.width / sourceSize.width
		let heightRatio = targetSize.height / sourceSize.height
		let scaleFactor = min(widthRatio, heightRatio)

		let scaledSize = NSSize(
			width: sourceSize.width * scaleFactor,
			height: sourceSize.height * scaleFactor
		)

		let resized = NSImage(size: targetSize)
		resized.lockFocus()

		NSColor.clear.setFill()
		NSRect(origin: .zero, size: targetSize).fill()

		NSGraphicsContext.current?.imageInterpolation = .high

		let xOffset = (targetSize.width - scaledSize.width) / 2
		let yOffset = (targetSize.height - scaledSize.height) / 2

		image.draw(
			in: NSRect(x: xOffset, y: yOffset, width: scaledSize.width, height: scaledSize.height),
			from: NSRect(origin: .zero, size: image.size),
			operation: .sourceOver,
			fraction: 1.0
		)

		resized.unlockFocus()
		return resized
	}

	static func clearCache() {
		iconCache.removeAllObjects()
		try? FileManager.default.removeItem(atPath: webIconsDir)
	}
}
