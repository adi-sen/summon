import Foundation

struct QueryHistoryEntry: Codable, Equatable {
	let query: String
	let timestamp: Double
}

class QueryHistoryManager {
	static let shared = QueryHistoryManager()

	private let userDefaults = UserDefaults.standard
	private let historyKey = "app_queryHistory"
	private let recentQueryTimeWindow: TimeInterval = 5 * 60

	private init() {}

	private var maxHistoryCount: Int {
		AppSettings.shared.maxQueryHistory
	}

	private var isEnabled: Bool {
		AppSettings.shared.enableQueryHistory
	}

	func addQuery(_ query: String) {
		guard isEnabled else { return }
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }

		let now = Date().timeIntervalSince1970
		var history = getHistory()

		history.removeAll { $0.query == trimmed }

		history.insert(QueryHistoryEntry(query: trimmed, timestamp: now), at: 0)

		history = Array(history.prefix(maxHistoryCount))

		saveHistory(history)
	}

	func getLastQuery() -> String? {
		guard isEnabled else { return nil }
		let history = getHistory()
		guard let lastEntry = history.first else { return nil }

		let now = Date().timeIntervalSince1970
		let elapsed = now - lastEntry.timestamp

		guard elapsed <= recentQueryTimeWindow else { return nil }

		return lastEntry.query
	}

	func getAllQueries() -> [String] {
		guard isEnabled else { return [] }
		return getHistory().map { $0.query }
	}

	private func getHistory() -> [QueryHistoryEntry] {
		guard let data = userDefaults.data(forKey: historyKey),
		      let history = try? JSONDecoder().decode([QueryHistoryEntry].self, from: data) else {
			return []
		}
		return history
	}

	private func saveHistory(_ history: [QueryHistoryEntry]) {
		guard let data = try? JSONEncoder().encode(history) else { return }
		userDefaults.set(data, forKey: historyKey)
	}

	func clearHistory() {
		userDefaults.removeObject(forKey: historyKey)
	}
}
