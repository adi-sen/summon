import SwiftUI

struct ClipboardPreview: View {
	let entry: ClipboardEntry
	@State private var thumbnail: NSImage?
	@State private var isLoading = false
	@State private var loadedTimestamp: TimeInterval?
	@ObservedObject var settings = AppSettings.shared

	var body: some View {
		Group {
			if entry.type == .image {
				if let thumb = thumbnail, loadedTimestamp == entry.timestamp {
					Image(nsImage: thumb)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(maxWidth: .infinity)
				} else if isLoading {
					Rectangle()
						.fill(Color.secondary.opacity(0.1))
						.frame(height: 200)
				} else {
					Rectangle()
						.fill(Color.secondary.opacity(0.1))
						.frame(height: 200)
						.onAppear {
							loadThumbnail()
						}
				}
			} else if entry.type == .text {
				Text(entry.content)
					.font(Font(settings.uiFont.withSize(13)))
					.foregroundColor(.primary)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
		}
		.onChange(of: entry.timestamp) { _ in
			thumbnail = nil
			loadedTimestamp = nil
			isLoading = false
			if entry.type == .image {
				loadThumbnail()
			}
		}
		.id(entry.timestamp)
	}

	private func loadThumbnail() {
		if loadedTimestamp == entry.timestamp, thumbnail != nil {
			return
		}

		guard !isLoading else { return }
		isLoading = true

		let currentTimestamp = entry.timestamp

		DispatchQueue.global(qos: .userInteractive).async {
			autoreleasepool {
				guard let filePath = entry.imageFilePath else {
					DispatchQueue.main.async {
						isLoading = false
					}
					return
				}

				let cacheKey = "thumb_\(currentTimestamp)"
				if let cached = ThumbnailCache.shared.get(cacheKey) {
					DispatchQueue.main.async {
						if entry.timestamp == currentTimestamp {
							thumbnail = cached
							loadedTimestamp = currentTimestamp
							isLoading = false
						}
					}
					return
				}

				guard let thumb = createThumbnailFast(from: filePath, maxSize: 250) else {
					DispatchQueue.main.async {
						isLoading = false
					}
					return
				}

				ThumbnailCache.shared.set(cacheKey, image: thumb)

				DispatchQueue.main.async {
					if entry.timestamp == currentTimestamp {
						thumbnail = thumb
						loadedTimestamp = currentTimestamp
						isLoading = false
					}
				}
			}
		}
	}

	private func createThumbnailFast(from filePath: String, maxSize: CGFloat) -> NSImage? {
		guard
			let imageSource = CGImageSourceCreateWithURL(
				URL(fileURLWithPath: filePath) as CFURL, nil
			)
		else {
			return nil
		}

		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceThumbnailMaxPixelSize: maxSize
		]

		guard
			let cgImage = CGImageSourceCreateThumbnailAtIndex(
				imageSource, 0, options as CFDictionary
			)
		else {
			return nil
		}

		let size = NSSize(width: cgImage.width, height: cgImage.height)
		let nsImage = NSImage(size: size)
		nsImage.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
		return nsImage
	}
}

struct MetadataRow: View {
	let label: String
	let value: String
	@ObservedObject var settings = AppSettings.shared

	var body: some View {
		HStack {
			Text(label)
				.font(Font(settings.uiFont.withSize(11)))
				.foregroundColor(.secondary)
				.frame(width: 70, alignment: .leading)

			Text(value)
				.font(Font(settings.uiFont.withSize(11)))
				.foregroundColor(.primary)
				.lineLimit(1)

			Spacer()
		}
	}
}
