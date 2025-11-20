import AppKit
import Foundation

struct DictionaryResult: Identifiable {
	var id: String { word }
	let word: String
	let definition: String
}

final class DictionaryService {
	func lookup(_ word: String) -> DictionaryResult? {
		let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return nil }

		guard
			let definitionRef = DCSCopyTextDefinition(nil, trimmed as CFString, CFRangeMake(0, trimmed.count)),
			let definition = definitionRef.takeRetainedValue() as String?
		else {
			return nil
		}

		return DictionaryResult(word: trimmed, definition: definition)
	}

	func hasDefinition(_ word: String) -> Bool {
		let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return false }

		if DCSCopyTextDefinition(nil, trimmed as CFString, CFRangeMake(0, trimmed.count)) != nil {
			return true
		}

		return false
	}
}
