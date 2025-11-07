import Cocoa
import Foundation

enum ClipboardItemType: UInt8 {
	case text = 0
	case image = 1
	case unknown = 2
}

struct ClipboardEntry {
	let content: String
	let timestamp: TimeInterval
	let type: ClipboardItemType
	let imageFilePath: String?
	let imageSize: NSSize?
	let size: Int32
	let sourceApp: String?

	var displayName: String {
		switch type {
		case .text:
			return String(content.prefix(80)) + (content.count > 80 ? "..." : "")
		case .image:
			if let imgSize = imageSize {
				return "Image (\(Int(imgSize.width))×\(Int(imgSize.height)))"
			}
			return "Image"
		case .unknown:
			return "Unknown"
		}
	}

	var mimeType: String {
		switch type {
		case .text: "text/plain"
		case .image: "image/png"
		case .unknown: "unknown"
		}
	}

	var formattedSize: String {
		let kb = Double(size) / 1024.0
		let mb = kb / 1024.0
		return mb >= 1.0 ? String(format: "%.2f MB", mb) : String(format: "%.2f KB", kb)
	}

	var formattedDate: String {
		let date = Date(timeIntervalSince1970: timestamp)
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .medium
		return formatter.string(from: date)
	}

	var timeAgo: String {
		let diff = Date().timeIntervalSince1970 - timestamp
		if diff < 60 { return "just now" }
		let (value, unit): (Int, String) = switch diff {
		case ..<3600: (Int(diff / 60), "min")
		case ..<86400: (Int(diff / 3600), "hour")
		default: (Int(diff / 86400), "day")
		}
		return "\(value) \(unit)\(value == 1 ? "" : "s") ago"
	}

	var fullImage: NSImage? {
		guard let filePath = imageFilePath,
		      FileManager.default.fileExists(atPath: filePath)
		else { return nil }
		return NSImage(contentsOfFile: filePath)
	}
}

final class ClipboardStorage {
	private var handle: FFI.ClipboardStorageHandle?
	private let storagePath: String
	private let imagesCacheDir: String

	init(appSupportDir: URL) {
		let storageURL = appSupportDir.appendingPathComponent("clipboard.rkyv")
		storagePath = storageURL.path

		let tempDir = NSTemporaryDirectory()
		imagesCacheDir = (tempDir as NSString).appendingPathComponent("SummonClipboard")

		try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
		try? FileManager.default.createDirectory(atPath: imagesCacheDir, withIntermediateDirectories: true)

		handle = FFI.clipboardStorageNew(path: storagePath)
	}

	deinit {
		FFI.clipboardStorageFree(handle)
	}

	func addText(content: String, sourceApp: String?, deduplicate: Bool = false) {
		if deduplicate {
			let entries = getAllEntries()
			if let index = entries.firstIndex(where: { $0.type == .text && $0.content == content }) {
				_ = FFI.clipboardStorageRemoveAt(handle, index: Int32(index))
			}
		}

		let timestamp = Date().timeIntervalSince1970
		let size = Int32(content.utf8.count)

		_ = FFI.clipboardStorageAddText(
			handle,
			content: content,
			timestamp: timestamp,
			size: size,
			sourceApp: sourceApp
		)
	}

	func addImage(_ image: NSImage, sourceApp: String?) {
		guard let tiffData = image.tiffRepresentation,
		      let bitmapImage = NSBitmapImageRep(data: tiffData),
		      let pngData = bitmapImage.representation(using: .png, properties: [:])
		else { return }

		let size = Int32(pngData.count)

		guard size < 10_000_000 else { // >10MB
			print("Skipping large image: \(size / 1024 / 1024) MB")
			return
		}

		let timestamp = Date().timeIntervalSince1970
		let filename = "clip_\(Int(timestamp * 1000)).png"
		let filePath = (imagesCacheDir as NSString).appendingPathComponent(filename)

		guard (try? pngData.write(to: URL(fileURLWithPath: filePath))) != nil else {
			print("Failed to save image to disk")
			return
		}

		let content = "Image (\(Int(image.size.width))×\(Int(image.size.height)))"

		_ = FFI.clipboardStorageAddImage(
			handle,
			content: content,
			timestamp: timestamp,
			imageFilePath: filePath,
			width: image.size.width,
			height: image.size.height,
			size: size,
			sourceApp: sourceApp
		)
	}

	func getEntries(start: Int = 0, count: Int = 100) -> [ClipboardEntry] {
		FFI.clipboardStorageGetEntries(handle, start: start, count: count).map { entry in
			ClipboardEntry(
				content: entry.content,
				timestamp: entry.timestamp,
				type: ClipboardItemType(rawValue: entry.itemType) ?? .unknown,
				imageFilePath: entry.imageFilePath,
				imageSize: (entry.imageWidth > 0 && entry.imageHeight > 0)
					? NSSize(width: entry.imageWidth, height: entry.imageHeight)
					: nil,
				size: entry.size,
				sourceApp: entry.sourceApp
			)
		}
	}

	func getAllEntries() -> [ClipboardEntry] {
		let totalCount = FFI.clipboardStorageLen(handle)
		return getEntries(start: 0, count: totalCount)
	}

	func count() -> Int {
		FFI.clipboardStorageLen(handle)
	}

	func trim(to maxEntries: Int) {
		guard FFI.clipboardStorageTrim(handle, maxEntries: maxEntries) else { return }
		cleanupOrphanedImageFiles()
	}

	func clear() {
		_ = FFI.clipboardStorageClear(handle)
		cleanupAllImageFiles()
	}

	private func cleanupOrphanedImageFiles() {
		let validPaths = Set(getAllEntries().compactMap(\.imageFilePath))
		try? FileManager.default.contentsOfDirectory(atPath: imagesCacheDir).forEach { file in
			let filePath = (imagesCacheDir as NSString).appendingPathComponent(file)
			if !validPaths.contains(filePath) {
				try? FileManager.default.removeItem(atPath: filePath)
			}
		}
	}

	private func cleanupAllImageFiles() {
		try? FileManager.default.contentsOfDirectory(atPath: imagesCacheDir).forEach { file in
			try? FileManager.default.removeItem(atPath: (imagesCacheDir as NSString).appendingPathComponent(file))
		}
	}
}
