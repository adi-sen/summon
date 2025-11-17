import Foundation

extension String {
	var fileExists: Bool {
		FileManager.default.fileExists(atPath: self)
	}

	var isValidApp: Bool {
		fileExists && hasSuffix(".app")
	}
}
