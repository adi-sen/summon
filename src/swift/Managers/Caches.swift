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

			// Update access order (move to end = most recently used)
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

			// Evict least recently used if over capacity
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

final class IconCache {
	static let shared = IconCache()

	private let cache = LRUCache<String, NSImage>(maxSize: 30, label: "com.invoke.iconcache")

	private init() {}

	func get(_ path: String) -> NSImage? {
		cache.get(path)
	}

	func set(_ path: String, icon: NSImage) {
		cache.set(path, value: icon)
	}

	func clear() {
		cache.clear()
	}
}

final class ThumbnailCache {
	static let shared = ThumbnailCache()

	private let cache = LRUCache<String, NSImage>(maxSize: 10, label: "com.invoke.thumbnailcache")

	private init() {}

	func get(_ key: String) -> NSImage? {
		cache.get(key)
	}

	func set(_ key: String, image: NSImage) {
		cache.set(key, value: image)
	}

	func clear() {
		cache.clear()
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
}
