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

final class IconCache {
	static let shared = IconCache()

	private let cache = NSCache<NSString, NSImage>()

	private init() {
		cache.countLimit = 30
		cache.totalCostLimit = 10 * 1024 * 1024
	}

	func get(_ path: String) -> NSImage? {
		cache.object(forKey: path as NSString)
	}

	func set(_ path: String, icon: NSImage) {
		let cost = Int(icon.size.width * icon.size.height * 4)
		cache.setObject(icon, forKey: path as NSString, cost: cost)
	}

	func clear() {
		cache.removeAllObjects()
	}
}

final class ThumbnailCache {
	static let shared = ThumbnailCache()

	private let cache = NSCache<NSString, NSImage>()

	private init() {
		cache.countLimit = 10
		cache.totalCostLimit = 5 * 1024 * 1024
	}

	func get(_ key: String) -> NSImage? {
		cache.object(forKey: key as NSString)
	}

	func set(_ key: String, image: NSImage) {
		let cost = Int(image.size.width * image.size.height * 4)
		cache.setObject(image, forKey: key as NSString, cost: cost)
	}

	func clear() {
		cache.removeAllObjects()
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
