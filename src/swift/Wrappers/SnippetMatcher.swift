import Foundation

final class SnippetMatcher {
	private var handle: FFI.SnippetMatcherHandle?

	init() {
		handle = FFI.snippetMatcherNew()
	}

	deinit {
		FFI.snippetMatcherFree(handle)
	}

	func updateSnippets(_ snippets: [Snippet]) {
		struct JsonSnippet: Codable {
			let id: String
			let trigger: String
			let content: String
			let enabled: Bool
		}

		let jsonSnippets = snippets.map { snippet in
			JsonSnippet(
				id: snippet.id,
				trigger: snippet.trigger,
				content: snippet.content,
				enabled: snippet.enabled
			)
		}

		guard let jsonData = try? JSONEncoder().encode(jsonSnippets),
		      let jsonString = String(data: jsonData, encoding: .utf8)
		else { return }

		_ = FFI.snippetMatcherUpdate(handle, json: jsonString)
	}

	func findMatch(in text: String) -> (trigger: String, content: String, matchEnd: Int)? {
		FFI.snippetMatcherFind(handle, text: text)
	}
}
