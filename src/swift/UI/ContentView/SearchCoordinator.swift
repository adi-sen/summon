import Foundation
import SwiftUI

@MainActor
class SearchCoordinator: ObservableObject {
	@Published var results: [CategoryResult] = []
	@Published var searchTimeMs: Double?
	@Published var isSearching: Bool = false

	private let searchEngine: SearchEngine
	private let settings: AppSettings
	private let calculator: Calculator
	private let dictionaryService = DictionaryService()
	private let searchDebouncer = Debouncer(delay: 0.05)
	private var searchGeneration = 0
	private var recentAppsCache: [String: Int] = [:]
	private var recentAppsCacheGeneration = -1
	private var resultBuffer: [CategoryResult] = []

	init(searchEngine: SearchEngine, settings: AppSettings, calculator: Calculator) {
		self.searchEngine = searchEngine
		self.settings = settings
		self.calculator = calculator
	}

	func performSearch(_ query: String) {
		searchDebouncer.cancel()
		searchGeneration += 1

		if query.isEmpty {
			results = []
			searchTimeMs = nil
			isSearching = false
			return
		}

		isSearching = true
		performActiveSearch(query: query, generation: searchGeneration)
	}

	func cancelSearch() {
		searchDebouncer.cancel()
		searchGeneration += 1
	}

	func resetResults() {
		results = []
		searchTimeMs = nil
		isSearching = false
	}

	private func performActiveSearch(query: String, generation: Int) {
		searchDebouncer.debounce { [weak self] in
			guard let self else { return }

			guard generation == self.searchGeneration else { return }

			let startTime = CFAbsoluteTimeGetCurrent()

			autoreleasepool {
				self.resultBuffer.removeAll(keepingCapacity: true)
				let maxResults = self.settings.maxResults

				autoreleasepool {
					if let (word, dictResult) = self.checkDictionaryMode(query) {
						if let result = dictResult {
							self.resultBuffer.append(self.createDictionaryResult(result))
						} else if !word.isEmpty {
							self.resultBuffer.append(self.createDictionaryNotFoundResult(word))
						}
					} else {
						if let calcResult = self.evaluateCalculator(query) {
							self.resultBuffer.append(self.createCalculatorResult(calcResult, query: query))
						}

						let appResults = self.searchEngine.search(query, limit: maxResults * 2)
						let validAppResults = self.filterValidApps(appResults)
						self.resultBuffer.append(contentsOf: self.createAppResults(validAppResults))

						let actionResults = ActionManager.shared.search(query: query)
						self.resultBuffer.append(contentsOf: self.createActionResults(actionResults))

						if self.shouldShowFallback(query: query, currentResults: self.resultBuffer) {
							self.resultBuffer.append(
								contentsOf: self.createFallbackResults(
									query: query, currentResults: self.resultBuffer
								))
						}

						self.resultBuffer.sort { $0.score > $1.score }
					}
				}

				let finalResults = Array(self.resultBuffer.prefix(maxResults))

				let endTime = CFAbsoluteTimeGetCurrent()
				let elapsedMs = (endTime - startTime) * 1000

				Task { @MainActor in
					guard generation == self.searchGeneration else { return }

					autoreleasepool {
						self.results = finalResults
						self.searchTimeMs = elapsedMs
						self.isSearching = false
					}

					malloc_zone_pressure_relief(nil, 0)
				}
			}
		}
	}

	private func createCalculatorResult(_ result: String, query: String) -> CategoryResult {
		let resultCopy = result
		let expression = query.trimmingCharacters(in: .whitespaces)

		return CategoryResult(
			id: "calc",
			name: result,
			category: "Calculator",
			path: expression,
			action: {
				let pasteboard = NSPasteboard.general
				pasteboard.clearContents()
				pasteboard.setString(resultCopy, forType: .string)
			},
			fullContent: nil,
			clipboardEntry: nil,
			icon: nil,
			score: 50
		)
	}

	private func createAppResults(_ appResults: [SearchResult]) -> [CategoryResult] {
		if recentAppsCacheGeneration != settings.recentAppsGeneration {
			recentAppsCache.removeAll(keepingCapacity: true)
			for (index, app) in settings.recentApps.enumerated() {
				recentAppsCache[app.path] = index
			}
			recentAppsCacheGeneration = settings.recentAppsGeneration
		}

		var results: [CategoryResult] = []
		results.reserveCapacity(appResults.count)

		for result in appResults {
			let isCommand = result.id.hasPrefix("cmd_")
			var score = result.score

			if let path = result.path, let recentIndex = recentAppsCache[path] {
				score += Int64(10000 - (recentIndex * 100))
			}

			results.append(
				CategoryResult(
					id: result.id,
					name: result.name,
					category: isCommand ? "Command" : "Applications",
					path: result.path,
					action: isCommand
						? {
							CommandRegistry.shared.executeCommand(id: result.id)
						} : nil,
					fullContent: nil,
					clipboardEntry: nil,
					icon: nil,
					score: score
				)
			)
		}

		return results
	}

	private func createActionResults(_ actionResults: [FFI.SwiftActionResult]) -> [CategoryResult] {
		var results: [CategoryResult] = []
		results.reserveCapacity(actionResults.count)

		for result in actionResults {
			let icon = ActionIconGenerator.loadIcon(
				iconName: result.icon,
				title: result.title,
				url: result.url
			)

			results.append(
				CategoryResult(
					id: result.id,
					name: result.title,
					category: "Action",
					path: result.subtitle,
					action: {
						if let url = URL(string: result.url), url.scheme != nil {
							NSWorkspace.shared.open(url)
						}
						NSApp.keyWindow?.orderOut(nil)
					},
					fullContent: nil,
					clipboardEntry: nil,
					icon: icon,
					score: Int64(result.score * 100)
				)
			)
		}

		return results
	}

	private func createFallbackResults(query: String, currentResults: [CategoryResult])
		-> [CategoryResult]
	{
		let availableSlots =
			settings.fallbackSearchBehavior == .appendToResults
				? settings.maxResults - currentResults.count
				: settings.maxResults
		let maxEngines = min(availableSlots, settings.fallbackSearchMaxEngines)

		var fallbackResults: [CategoryResult] = []

		for engineId in settings.fallbackSearchEngines.prefix(maxEngines) {
			guard let engine = settings.fallbackEngineById(engineId) else { continue }

			let encodedQuery =
				query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
			let searchURL = engine.urlTemplate.replacingOccurrences(
				of: "{query}", with: encodedQuery
			)

			var icon: NSImage?
			if engine.iconName.hasPrefix("web:") {
				let iconName = String(engine.iconName.dropFirst(4))
				WebIconDownloader.getIcon(for: iconName, size: NSSize(width: 28, height: 28)) {
					loadedIcon in
					icon = loadedIcon
				}
			}

			if icon == nil {
				icon = ActionIconGenerator.loadIcon(
					iconName: engine.iconName,
					title: engine.name,
					url: searchURL
				)
			}

			fallbackResults.append(
				CategoryResult(
					id: "fallback_\(engine.id)",
					name: "Search with \(engine.name)",
					category: "Web",
					path: searchURL,
					action: {
						if let url = URL(string: searchURL) {
							NSWorkspace.shared.open(url)
						}
						NSApp.keyWindow?.orderOut(nil)
					},
					fullContent: nil,
					clipboardEntry: nil,
					icon: icon,
					score: 0
				)
			)
		}

		return fallbackResults
	}

	private func filterValidApps(_ appResults: [SearchResult]) -> [SearchResult] {
		let fileManager = FileManager.default

		return appResults.filter { result in
			if result.id.hasPrefix("cmd_") {
				return true
			}

			guard let path = result.path else {
				return true
			}

			let exists = fileManager.fileExists(atPath: path)

			if let appDelegate = AppDelegate.shared {
				let wasCachedInvalid = appDelegate.isKnownInvalidApp(path: path)

				if exists, wasCachedInvalid {
					Task { @MainActor in
						appDelegate.markAppAsValid(path: path)
					}
				} else if !exists, !wasCachedInvalid {
					print("Filtering out non-existent app from results: \(result.name) at \(path)")
					Task { @MainActor in
						appDelegate.markAppAsInvalid(path: path)
					}
				} else if !exists {
					return false
				}
			}

			return exists
		}
	}

	private func shouldShowFallback(query: String, currentResults: [CategoryResult]) -> Bool {
		guard settings.enableFallbackSearch else { return false }
		guard query.count >= settings.fallbackSearchMinQueryLength else { return false }

		if settings.fallbackSearchBehavior == .onlyWhenEmpty {
			return currentResults.isEmpty
		} else {
			return currentResults.count < settings.maxResults
		}
	}

	private func evaluateCalculator(_ query: String) -> String? {
		let trimmed = query.trimmingCharacters(in: .whitespaces)
		guard trimmed.count >= 3 else { return nil }

		let hasNumber = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
		let hasMathOp =
			trimmed.contains("+") || trimmed.contains("-") || trimmed.contains("*")
			|| trimmed.contains("/") || trimmed.contains("^")
		let hasCurrency =
			trimmed.uppercased().range(
				of: #"\b(USD|EUR|GBP|JPY|CNY|AUD|CAD|CHF|INR|KRW)\b"#,
				options: .regularExpression
			) != nil
		let hasFunction =
			trimmed.lowercased().contains("sqrt")
			|| trimmed.lowercased().contains("sin")
			|| trimmed.lowercased().contains("cos")
			|| trimmed.lowercased().contains("tan")
			|| trimmed.lowercased().contains("log")

		guard hasNumber, hasMathOp || hasCurrency || hasFunction else { return nil }

		return calculator.evaluate(trimmed)
	}

	private func checkDictionaryMode(_ query: String) -> (String, DictionaryResult?)? {
		guard settings.enableDictionary else { return nil }

		let trimmed = query.trimmingCharacters(in: .whitespaces)
		let prefix = settings.dictionaryPrefix.lowercased()

		guard !prefix.isEmpty else { return nil }

		let trimmedLower = trimmed.lowercased()
		let searchPrefix = prefix.hasSuffix(":") ? prefix : prefix + ":"

		if trimmedLower.hasPrefix(searchPrefix) {
			let word = String(trimmed.dropFirst(searchPrefix.count)).trimmingCharacters(
				in: .whitespaces
			)
			return (word, word.isEmpty ? nil : dictionaryService.lookup(word))
		} else if trimmedLower.hasPrefix(prefix + " ") {
			let word = String(trimmed.dropFirst(prefix.count + 1)).trimmingCharacters(
				in: .whitespaces
			)
			return (word, word.isEmpty ? nil : dictionaryService.lookup(word))
		}

		return nil
	}

	private func createDictionaryResult(_ result: DictionaryResult) -> CategoryResult {
		let cleanDefinition = cleanDefinitionForCopy(result.definition)
		let wordCopy = result.word

		return CategoryResult(
			id: "dict_\(result.word)",
			name: result.word,
			category: "Dictionary",
			path: result.definition,
			action: {
				let copyText = "\(wordCopy)\n\n\(cleanDefinition)"
				let pasteboard = NSPasteboard.general
				pasteboard.clearContents()
				pasteboard.setString(copyText, forType: .string)
			},
			fullContent: result.definition,
			clipboardEntry: nil,
			icon: nil,
			score: 0
		)
	}

	private func cleanDefinitionForCopy(_ definition: String) -> String {
		var result = definition

		result = result.replacingOccurrences(
			of: #"\s*\(also[^)]*\)"#, with: "", options: .regularExpression
		)
		result = result.replacingOccurrences(
			of: #"\s*\|[^|]*\|"#, with: "", options: .regularExpression
		)

		let parts = result.components(separatedBy: CharacterSet(charactersIn: ".;"))
		var cleaned: [String] = []
		var defNumber = 1

		let posPatterns = ["noun", "verb", "adjective", "adverb", "exclamation", "preposition", "conjunction", "pronoun"]

		for part in parts {
			let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmed.isEmpty else { continue }

			let lowerTrimmed = trimmed.lowercased()

			if lowerTrimmed.hasPrefix("origin") {
				break
			}

			if trimmed.hasPrefix("\"") || trimmed.contains("example") || trimmed.count < 10 {
				continue
			}

			if posPatterns.contains(where: { lowerTrimmed.contains($0) }) {
				if let pos = posPatterns.first(where: { lowerTrimmed.contains($0) }) {
					cleaned.append("\n\(pos)")
					defNumber = 1
					continue
				}
			}

			cleaned.append("\(defNumber). \(trimmed)")
			defNumber += 1
		}

		return cleaned.joined(separator: "\n")
	}

	private func createDictionaryNotFoundResult(_ word: String) -> CategoryResult {
		let message = "No definition found for '\(word)'"

		return CategoryResult(
			id: "dict_notfound_\(word)",
			name: word,
			category: "DictionaryNotFound",
			path: message,
			action: nil,
			fullContent: message,
			clipboardEntry: nil,
			icon: nil,
			score: 0
		)
	}
}
