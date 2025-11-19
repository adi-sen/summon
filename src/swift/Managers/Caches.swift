import SwiftUI

final class LRUCache<Key: Hashable, Value> {
	private var cache: [Key: Value] = [:]
	private var accessOrder: [Key] = []
	private let maxSize: Int
	private let queue: DispatchQueue

	init(maxSize: Int, label: String = "com.invoke.lrucache") {
		self.maxSize = maxSize
		self.queue = DispatchQueue(label: "\(label).\(UUID().uuidString)")
	}

	func get(_ key: Key) -> Value? {
		queue.sync {
			guard let value = cache[key] else { return nil }

			if let index = accessOrder.firstIndex(of: key) {
				accessOrder.remove(at: index)
				accessOrder.append(key)
			}

			return value
		}
	}

	func set(_ key: Key, value: Value) {
		queue.sync {
			cache[key] = value

			if let index = accessOrder.firstIndex(of: key) {
				accessOrder.remove(at: index)
			}

			accessOrder.append(key)

			while accessOrder.count > maxSize {
				let oldest = accessOrder.removeFirst()
				cache.removeValue(forKey: oldest)
			}
		}
	}

	func clear() {
		queue.sync {
			cache.removeAll()
			accessOrder.removeAll()
		}
	}

	func count() -> Int {
		queue.sync {
			cache.count
		}
	}
}

final class ImageCache {
	static let icon = ImageCache(maxSize: 100)
	static let thumbnail = ImageCache(maxSize: 30)

	private let cache: LRUCache<String, NSImage>

	init(maxSize: Int) {
		cache = LRUCache<String, NSImage>(maxSize: maxSize)
	}

	func get(_ key: String) -> NSImage? {
		cache.get(key)
	}

	func set(_ key: String, image: NSImage) {
		cache.set(key, value: image)
	}

	func clear() {
		cache.clear()
	}

	func count() -> Int {
		cache.count()
	}
}

struct CategoryResult: Identifiable {
	let id: String
	let name: String
	let category: String
	let path: String?
	let action: (() -> Void)?
	let fullContent: String?
	let clipboardEntry: ClipboardEntry?
	let icon: NSImage?
	let score: Int64

	var isApp: Bool {
		category == "Applications" || category == "Pinned" || category == "Recent"
	}

	var isCommand: Bool {
		category == "Command"
	}
}
