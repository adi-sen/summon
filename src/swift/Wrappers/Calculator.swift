import Foundation

struct CalculationEntry: Codable, Identifiable {
	var id: String { query + result }
	let query: String
	let result: String
}

final class Calculator: ObservableObject {
	private var handle: FFI.CalculatorHandle?
	@Published var history: [CalculationEntry] = []

	init() {
		handle = FFI.calculatorNew()
	}

	deinit {
		FFI.calculatorFree(handle)
	}

	func evaluate(_ query: String) -> String? {
		let result = FFI.calculatorEvaluate(handle, query: query)
		updateHistory()
		return result
	}

	func updateHistory() {
		guard let jsonString = FFI.calculatorGetHistoryJSON(handle),
		      let data = jsonString.data(using: .utf8),
		      let entries = try? JSONDecoder().decode([CalculationEntry].self, from: data)
		else { return }

		DispatchQueue.main.async {
			self.history = entries.reversed()
		}
	}

	func clearHistory() {
		FFI.calculatorClearHistory(handle)
		history = []
	}
}
