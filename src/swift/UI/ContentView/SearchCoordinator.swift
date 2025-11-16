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
    private var searchTask: DispatchWorkItem?
    private var searchGeneration = 0
    private var recentAppsCache: [String: Int] = [:]
    private var recentAppsCacheGeneration = -1

    init(searchEngine: SearchEngine, settings: AppSettings, calculator: Calculator) {
        self.searchEngine = searchEngine
        self.settings = settings
        self.calculator = calculator
    }

    func performSearch(_ query: String) {
        searchTask?.cancel()
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
        searchTask?.cancel()
        searchGeneration += 1
    }

    func resetResults() {
        results = []
        searchTimeMs = nil
        isSearching = false
    }

    private func performActiveSearch(query: String, generation: Int) {
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }

            guard generation == self.searchGeneration else { return }

            let startTime = CFAbsoluteTimeGetCurrent()

            autoreleasepool {
                var allResults: [CategoryResult] = []
                let maxResults = self.settings.maxResults

                if let calcResult = self.evaluateCalculator(query) {
                    allResults.append(self.createCalculatorResult(calcResult, query: query))
                }

                let appResults = self.searchEngine.search(query, limit: maxResults)
                let validAppResults = self.filterValidApps(appResults)
                allResults.append(contentsOf: self.createAppResults(validAppResults))

                let actionResults = ActionManager.shared.search(query: query)
                allResults.append(contentsOf: self.createActionResults(actionResults))

                if self.shouldShowFallback(query: query, currentResults: allResults) {
                    allResults.append(
                        contentsOf: self.createFallbackResults(
                            query: query, currentResults: allResults
                        ))
                }

                allResults.sort { $0.score > $1.score }
                allResults = Array(allResults.prefix(maxResults))

                let endTime = CFAbsoluteTimeGetCurrent()
                let elapsedMs = (endTime - startTime) * 1000

                Task { @MainActor in
                    guard generation == self.searchGeneration else { return }

                    autoreleasepool {
                        self.results = allResults
                        self.searchTimeMs = elapsedMs
                        self.isSearching = false
                    }

                    malloc_zone_pressure_relief(nil, 0)
                }
            }
        }

        searchTask = task
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05, execute: task)
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
            recentAppsCache = Dictionary(
                uniqueKeysWithValues: settings.recentApps.enumerated().map { ($1.path, $0) }
            )
            recentAppsCacheGeneration = settings.recentAppsGeneration
        }

        return appResults.map { result in
            let isCommand = result.id.hasPrefix("cmd_")
            var score = result.score

            if let path = result.path, let recentIndex = recentAppsCache[path] {
                score += Int64(10000 - (recentIndex * 100))
            }

            return CategoryResult(
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
        }
    }

    private func createActionResults(_ actionResults: [FFI.SwiftActionResult]) -> [CategoryResult] {
        actionResults.map { result in
            let icon = ActionIconGenerator.loadIcon(
                iconName: result.icon,
                title: result.title,
                url: result.url
            )

            return CategoryResult(
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
        }
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
}
