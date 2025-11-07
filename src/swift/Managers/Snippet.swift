import Foundation

final class SnippetManager: ObservableObject {
	static let shared = SnippetManager()

	@Published var snippets: [Snippet] = [] {
		didSet {
			matcher.updateSnippets(snippets)
		}
	}

	private let storage: SnippetStorage
	private let matcher = SnippetMatcher()

	init() {
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let appDir = appSupport.appendingPathComponent("Summon")
		storage = SnippetStorage(appSupportDir: appDir)
		load()
		matcher.updateSnippets(snippets)
	}

	func load() {
		snippets = storage.getAll()
		if snippets.isEmpty {
			snippets = SnippetStorage.createDefaultSnippets()
			for snippet in snippets {
				storage.add(snippet)
			}
		}
	}

	func add(_ snippet: Snippet) {
		snippets.append(snippet)
		storage.add(snippet)
	}

	func update(_ snippet: Snippet) {
		if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
			snippets[index] = snippet
			storage.update(snippet)
		}
	}

	func delete(_ snippet: Snippet) {
		snippets.removeAll { $0.id == snippet.id }
		storage.delete(id: snippet.id)
	}

	func findMatch(in text: String) -> (trigger: String, content: String)? {
		if let match = matcher.findMatch(in: text) {
			return (match.trigger, match.content)
		}
		return nil
	}
}
