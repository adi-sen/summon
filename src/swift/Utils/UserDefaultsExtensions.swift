import Foundation

extension UserDefaults {
	func decodable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
		guard let data = data(forKey: key) else { return nil }
		return try? JSONDecoder().decode(type, from: data)
	}

	func setEncodable<T: Encodable>(_ value: T, forKey key: String) {
		guard let data = try? JSONEncoder().encode(value) else { return }
		set(data, forKey: key)
	}
}
