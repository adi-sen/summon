import Cocoa

final class ClipboardManager {
	private let storage: ClipboardStorage
	private var lastChangeCount: Int = 0
	private var checkTimer: DispatchSourceTimer?
	private let queue = DispatchQueue(label: "com.invoke.clipboard", qos: .userInitiated)
	private var ignoreNextChange = false

	init() {
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let appDir = appSupport.appendingPathComponent("Summon")
		storage = ClipboardStorage(appSupportDir: appDir)
	}

	deinit {
		stop()
	}

	func start() {
		let timer = DispatchSource.makeTimerSource(queue: queue)
		timer.schedule(deadline: .now(), repeating: .milliseconds(200))
		timer.setEventHandler { [weak self] in
			self?.checkClipboard()
		}
		timer.resume()
		checkTimer = timer
	}

	func stop() {
		checkTimer?.cancel()
		checkTimer = nil
	}

	func forceRefresh() {
		queue.async { [weak self] in
			self?.checkClipboard()
		}
	}

	private func checkClipboard() {
		autoreleasepool {
			let pasteboard = NSPasteboard.general
			let currentChangeCount = pasteboard.changeCount

			guard currentChangeCount != lastChangeCount else { return }
			lastChangeCount = currentChangeCount

			if ignoreNextChange {
				ignoreNextChange = false
				return
			}

			let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName

			if let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
				storage.addImage(image, sourceApp: sourceApp)
				return
			}

			if let content = pasteboard.string(forType: .string), !content.isEmpty {
				addTextEntry(content, sourceApp: sourceApp)
				return
			}
		}
	}

	func willCopyToClipboard() {
		ignoreNextChange = true
	}

	private func addTextEntry(_ content: String, sourceApp: String?) {
		let maxContentSize = 1_048_576
		let truncatedContent = content.count > maxContentSize
			? String(content.prefix(maxContentSize))
			: content

		storage.addText(content: truncatedContent, sourceApp: sourceApp, deduplicate: true)
		trimHistory()
	}

	private func trimHistory() {
		let maxHistory = AppSettings.shared.maxClipboardItems
		storage.trim(to: maxHistory)
	}

	func getHistory() -> [ClipboardEntry] {
		storage.getEntries(start: 0, count: AppSettings.shared.maxClipboardItems)
	}

	func clear() {
		storage.clear()
	}

	func cleanupOldEntries() {
		autoreleasepool {
			let retentionDays = AppSettings.shared.clipboardRetentionDays
			let cutoffTime = Date().timeIntervalSince1970 - (Double(retentionDays) * 24 * 60 * 60)

			let allEntries = storage.getAllEntries()
			let validEntries = allEntries.filter { $0.timestamp >= cutoffTime }

			let maxHistory = AppSettings.shared.maxClipboardItems
			if validEntries.count > maxHistory {
				storage.trim(to: maxHistory)
			}
		}
	}

	func moveToTop(at index: Int) {
		let entries = getHistory()
		guard index < entries.count else { return }
		let entry = entries[index]

		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()

		switch entry.type {
		case .text:
			pasteboard.setString(entry.content, forType: .string)
		case .image:
			if let image = entry.fullImage {
				pasteboard.writeObjects([image])
			}
		case .unknown:
			break
		}
	}
}
