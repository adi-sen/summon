import Foundation

struct SearchResult: Identifiable {
	let id: String
	let name: String
	let path: String?
	let score: Int64
}

struct IndexStats {
	let total: Int
	let apps: Int
	let files: Int
	let snippets: Int
}

final class SearchEngine {
	private var handle: FFI.SearchEngineHandle?

	init() {
		handle = FFI.searchEngineNew()
	}

	deinit {
		FFI.searchEngineFree(handle)
	}

	func addApplication(id: String, name: String, path: String) {
		_ = FFI.searchEngineAddItem(handle, id: id, name: name, path: path, itemType: 0)
	}

	func addFile(id: String, name: String, path: String) {
		_ = FFI.searchEngineAddItem(handle, id: id, name: name, path: path, itemType: 1)
	}

	func addCommand(id: String, name: String, keywords: [String]) {
		_ = FFI.searchEngineAddItem(handle, id: id, name: name, path: keywords.joined(separator: " "), itemType: 4)
	}

	func search(_ query: String, limit: Int = 10) -> [SearchResult] {
		FFI.searchEngineSearch(handle, query: query, limit: limit).map { result in
			SearchResult(id: result.id, name: result.name, path: result.path, score: result.score)
		}
	}

	func stats() -> IndexStats {
		let stats = FFI.searchEngineStats(handle)
		return IndexStats(
			total: stats.total,
			apps: stats.apps,
			files: stats.files,
			snippets: stats.snippets
		)
	}

	func clear() {
		FFI.searchEngineFree(handle)
		handle = FFI.searchEngineNew()
	}

	func scanForNewApps(directories: [String], excludePatterns: [String]) -> Int {
		FFI.searchEngineScanApps(handle, directories: directories, excludePatterns: excludePatterns)
	}

	func getAllApps() -> [(name: String, path: String)] {
		FFI.searchEngineGetApps(handle)
	}
}
