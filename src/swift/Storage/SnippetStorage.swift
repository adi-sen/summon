import Foundation

struct Snippet: Identifiable, Codable {
	var id: String
	var trigger: String
	var content: String
	var enabled: Bool
	var category: String

	init(
		id: String = UUID().uuidString,
		trigger: String,
		content: String,
		enabled: Bool = true,
		category: String = "General"
	) {
		self.id = id
		self.trigger = trigger
		self.content = content
		self.enabled = enabled
		self.category = category
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(String.self, forKey: .id)
		trigger = try container.decode(String.self, forKey: .trigger)
		content = try container.decode(String.self, forKey: .content)
		enabled = try container.decode(Bool.self, forKey: .enabled)
		category = try container.decodeIfPresent(String.self, forKey: .category) ?? "General"
	}
}

final class SnippetStorage {
	private var handle: FFI.SnippetStorageHandle?
	private let storagePath: String

	init(appSupportDir: URL) {
		let storageURL = appSupportDir.appendingPathComponent("snippets.rkyv")
		storagePath = storageURL.path

		try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

		handle = FFI.snippetStorageNew(path: storagePath)
	}

	deinit {
		FFI.snippetStorageFree(handle)
	}

	func add(_ snippet: Snippet) {
		_ = FFI.snippetStorageAdd(
			handle,
			id: snippet.id,
			trigger: snippet.trigger,
			content: snippet.content,
			enabled: snippet.enabled,
			category: snippet.category
		)
	}

	func update(_ snippet: Snippet) {
		_ = FFI.snippetStorageUpdate(
			handle,
			id: snippet.id,
			trigger: snippet.trigger,
			content: snippet.content,
			enabled: snippet.enabled,
			category: snippet.category
		)
	}

	func delete(id: String) {
		_ = FFI.snippetStorageDelete(handle, id: id)
	}

	func getAll() -> [Snippet] {
		let swiftSnippets = FFI.snippetStorageGetAll(handle)
		return swiftSnippets.map { swiftSnippet in
			Snippet(
				id: swiftSnippet.id,
				trigger: swiftSnippet.trigger,
				content: swiftSnippet.content,
				enabled: swiftSnippet.enabled,
				category: swiftSnippet.category
			)
		}
	}

	func getEnabled() -> [Snippet] {
		let swiftSnippets = FFI.snippetStorageGetEnabled(handle)
		return swiftSnippets.map { swiftSnippet in
			Snippet(
				id: swiftSnippet.id,
				trigger: swiftSnippet.trigger,
				content: swiftSnippet.content,
				enabled: swiftSnippet.enabled,
				category: swiftSnippet.category
			)
		}
	}

	func count() -> Int {
		FFI.snippetStorageLen(handle)
	}

	static func createDefaultSnippets() -> [Snippet] {
		[
			Snippet(trigger: "\\email", content: "your@email.com"),
			Snippet(trigger: "\\phone", content: "123-456-7890"),
			Snippet(trigger: "\\address", content: "123 Main St, City, State 12345")
		]
	}
}
