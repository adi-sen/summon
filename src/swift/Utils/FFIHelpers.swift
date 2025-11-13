import Foundation

enum FFIHelpers {
	static func convertCStringArray<T>(
		_ ptr: UnsafeMutablePointer<T>?,
		count: Int,
		transform: (T) -> String?
	) -> [String] {
		guard let ptr, count > 0 else { return [] }

		var result: [String] = []
		result.reserveCapacity(count)

		for i in 0 ..< count {
			if let value = transform(ptr[i]) {
				result.append(value)
			}
		}

		return result
	}

	static func safeString(from ptr: UnsafeMutablePointer<CChar>?) -> String? {
		guard let ptr else { return nil }
		return String(cString: ptr)
	}

	static func withOptionalCString<R>(_ str: String?, _ body: (UnsafePointer<CChar>?) -> R) -> R {
		guard let str else { return body(nil) }
		return str.withCString(body)
	}

	static func convertCArray<C, S>(
		_ cArray: UnsafeMutablePointer<C>?,
		count: Int,
		converter: (C) -> S?
	) -> [S] {
		guard let cArray, count > 0 else { return [] }

		var swiftArray: [S] = []
		swiftArray.reserveCapacity(count)

		for i in 0 ..< count {
			if let converted = converter(cArray[i]) {
				swiftArray.append(converted)
			}
		}

		return swiftArray
	}
}
