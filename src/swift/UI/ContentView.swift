import Carbon
import SwiftUI

struct ContentView: View {
	@ObservedObject var searchEngine: SearchEngine
	@ObservedObject var settings = AppSettings.shared
	let clipboardManager: ClipboardManager
	@ObservedObject var calculator: Calculator

	init(searchEngine: SearchEngine, clipboardManager: ClipboardManager) {
		self.searchEngine = searchEngine
		self.clipboardManager = clipboardManager
		calculator = Calculator()
	}

	@State private var searchText = ""
	@State private var results: [CategoryResult] = []
	@State private var selectedIndex = 0
	@State private var searchTask: DispatchWorkItem?
	@State private var clipboardHistory: [ClipboardEntry] = []

	private var windowHeight: CGFloat {
		let maxVisibleRows = 7
		let actualRows = min(results.count, maxVisibleRows)
		let visibleRows = max(0, actualRows)
		let footerHeight: CGFloat = shouldShowFooter ? 32 : 0

		let searchBarHeight: CGFloat = 52
		let dividerHeight: CGFloat = 1
		let topPadding: CGFloat = 4
		let rowHeight: CGFloat = 44
		let bottomBuffer: CGFloat = 1

		if settings.compactMode && !isClipboardMode {
			if visibleRows == 0 {
				return searchBarHeight
			}
			return searchBarHeight + dividerHeight + topPadding + CGFloat(visibleRows) * rowHeight + bottomBuffer + footerHeight
		} else {
			return searchBarHeight + dividerHeight + topPadding + CGFloat(maxVisibleRows) * rowHeight + bottomBuffer + footerHeight
		}
	}

	private var shouldShowFooter: Bool {
		guard settings.showFooterHints else { return false }

		// In non-compact mode, always show footer
		if !settings.compactMode {
			return true
		}

		// In compact mode, show footer conditionally
		if isClipboardMode {
			return !results.isEmpty && selectedIndex < clipboardHistory.count
		}

		if results.isEmpty {
			return false
		}

		if selectedIndex < results.count {
			let selectedResult = results[selectedIndex]
			let isApp = selectedResult.category == "Applications" || selectedResult.category == "Pinned" || selectedResult.category == "Recent"
			let isCommand = selectedResult.category == "Command"
			let isAction = selectedResult.category == "Action" || selectedResult.category == "Web"

			if isApp || isCommand || isAction {
				return true
			}
		}

		return false
	}

	@State private var isClipboardMode = false
	@State private var clipboardPage = 0
	@State private var clipboardPageSize = 9
	@State private var searchGeneration = 0
	@State private var eventMonitor: Any?
	@State private var searchTimeMs: Double?
	@State private var selectedAppInfo: AppInfo?
	@State private var showSecondaryHints = false
	@State private var appIcon: NSImage?
	var onOpenSettings: (() -> Void)?

	struct AppInfo {
		let name: String
		let path: String
		let size: String
		let version: String?
	}

	private func isAppRunning(path: String) -> Bool {
		NSWorkspace.shared.runningApplications.contains { app in
			app.bundleURL?.path == path
		}
	}

	private func getAppHints(for result: CategoryResult, identifier: String) -> [HintAction] {
		let isCommand = result.category == "Command"
		let isPinned = settings.pinnedApps.contains { $0.path == identifier }

		if isCommand {
			return [HintAction(shortcut: settings.pinAppShortcut.displayString, label: isPinned ? "Unpin" : "Pin")]
		}

		let running = isAppRunning(path: identifier)

		if showSecondaryHints {
			var hints: [HintAction] = [HintAction(shortcut: settings.copyPathShortcut.displayString, label: "Copy Path")]
			if running {
				hints.insert(HintAction(shortcut: settings.quitAppShortcut.displayString, label: "Quit App"), at: 0)
				hints.insert(HintAction(shortcut: settings.hideAppShortcut.displayString, label: "Hide App"), at: 1)
			}
			return hints
		} else {
			var hints: [HintAction] = []
			if running {
				hints.append(HintAction(shortcut: settings.quitAppShortcut.displayString, label: "Quit"))
				hints.append(HintAction(shortcut: settings.hideAppShortcut.displayString, label: "Hide"))
			}
			hints.append(HintAction(shortcut: settings.pinAppShortcut.displayString, label: isPinned ? "Unpin" : "Pin"))
			if !running {
				hints.append(HintAction(shortcut: settings.revealAppShortcut.displayString, label: "Reveal"))
			}
			return hints
		}
	}

	private var placeholderText: String {
		isClipboardMode ? "Type to filter entries..." : "Search applications..."
	}

	var body: some View {
		ZStack {
			VStack(spacing: 0) {
				HStack(spacing: DesignTokens.Spacing.md + 2) {
					SearchField(
						text: $searchText,
						placeholder: placeholderText,
						quickSelectModifier: settings.quickSelectModifier,
						font: settings.uiFont,
						onSubmit: launchSelected,
						onEscape: handleEscape,
						onUpArrow: {
							if selectedIndex > 0 {
								selectedIndex -= 1
							}
						},
						onDownArrow: {
							if selectedIndex < results.count - 1 {
								selectedIndex += 1
							}
						},
						onAltNumber: { number in
							handleAltNumber(number)
						}
					)
					.frame(height: 36)
				}
				.padding(.horizontal, DesignTokens.Spacing.lg)
				.padding(.vertical, DesignTokens.Spacing.md)
				.background(settings.backgroundColorUI)
				.zIndex(1000)

				if !results.isEmpty || !settings.compactMode {
					Divider()
						.opacity(0.5)
				}

				if !results.isEmpty {
					HStack(spacing: 0) {
						ScrollViewReader { proxy in
							ScrollView(showsIndicators: false) {
								LazyVStack(alignment: .leading, spacing: 0) {
									ForEach(Array(results.enumerated()), id: \.element.id) {
										index, result in
										ResultRow(
											result: result,
											isSelected: index == selectedIndex,
											hideCategory: isClipboardMode,
											quickSelectNumber: index < 9 ? index + 1 : nil
										)
										.id(index)
										.contentShape(Rectangle())
										.onTapGesture {
											selectedIndex = index
											launchSelected()
										}
										.onHover { isHovering in
											if isHovering {
												selectedIndex = index
											}
										}
									}
									.padding(.top, 4)
								}
								.onChange(of: selectedIndex) { newIndex in
									withAnimation(.easeInOut(duration: 0.15)) {
										proxy.scrollTo(newIndex, anchor: .center)
									}
									selectedAppInfo = nil
								}
							}
						}
						.frame(maxWidth: showPreview ? 225 : .infinity)
						.background(settings.backgroundColorUI)

						if showPreview, let entry = selectedClipboardEntry {
							Divider()

							VStack(spacing: 0) {
								ScrollView {
									VStack(alignment: .leading, spacing: 8) {
										ClipboardPreview(entry: entry)
									}
									.padding(DesignTokens.Spacing.md + 2)
								}
								.background(settings.backgroundColorUI)

								Divider()
									.background(Color.white.opacity(0.1))

								VStack(alignment: .leading, spacing: 6) {
									if let sourceApp = entry.sourceApp {
										MetadataRow(label: "Source", value: sourceApp)
									}
									MetadataRow(label: "Mime", value: entry.mimeType)
									MetadataRow(label: "Size", value: entry.formattedSize)
									MetadataRow(label: "Copied at", value: entry.formattedDate)
								}
								.padding(DesignTokens.Spacing.md + 2)
								.background(settings.backgroundColorUI)
							}
							.frame(width: 375)
							.background(settings.backgroundColorUI)
						}
					}
				} else if !searchText.isEmpty, !isClipboardMode {
					VStack {
						Spacer()
						VStack(spacing: DesignTokens.Spacing.md) {
							Image(systemName: "magnifyingglass")
								.font(.system(size: 48))
								.foregroundColor(.secondary.opacity(0.5))
							Text("No results")
								.font(.system(size: 15))
								.foregroundColor(.secondary)
						}
						Spacer()
					}
					.background(settings.backgroundColorUI)
				} else if searchText.isEmpty, !isClipboardMode {
					EmptyView()
				} else if isClipboardMode, results.isEmpty {
					VStack {
						Spacer()
						VStack(spacing: DesignTokens.Spacing.md) {
							Image(systemName: "doc.on.clipboard")
								.font(.system(size: 48))
								.foregroundColor(settings.secondaryTextColorUI.opacity(0.4))
							Text("No clipboard items")
								.font(.system(size: 15))
								.foregroundColor(settings.secondaryTextColorUI)
						}
						Spacer()
					}
					.background(settings.backgroundColorUI)
				}

				if shouldShowFooter {
					Divider()
						.opacity(0.3)

					HStack(spacing: DesignTokens.Spacing.md) {
						if let icon = appIcon {
							Image(nsImage: icon)
								.resizable()
								.frame(width: 18, height: 18)
								.padding(.leading, DesignTokens.Spacing.md)
						}

						if isClipboardMode, selectedIndex < clipboardHistory.count {
							let entry = clipboardHistory[selectedIndex]
							if entry.type == .text {
								ContextualHints(hints: [
									HintAction(shortcut: settings.saveClipboardShortcut.displayString, label: "Save as text expansion")
								])
							} else if entry.type == .image {
								ContextualHints(hints: [
									HintAction(shortcut: settings.saveClipboardShortcut.displayString, label: "Save to Pictures")
								])
							}
						} else if !isClipboardMode, selectedIndex < results.count {
							let selectedResult = results[selectedIndex]
							let isApp = selectedResult.category == "Applications" || selectedResult.category == "Pinned" || selectedResult.category == "Recent"
							let isCommand = selectedResult.category == "Command"
							let isAction = selectedResult.category == "Action" || selectedResult.category == "Web"

							if isApp {
								if let appInfo = selectedAppInfo {
									AppInfoDisplay(info: appInfo)
								} else if let path = selectedResult.path {
									ContextualHints(hints: getAppHints(for: selectedResult, identifier: path))
								}
							} else if isCommand || isAction {
								let hints = isCommand
									? getAppHints(for: selectedResult, identifier: selectedResult.id)
									: [HintAction(shortcut: "↩", label: "Open")]
								ContextualHints(hints: hints)
							}
						}

						Spacer()

						if !isClipboardMode, let searchTimeMs {
							SearchMetrics(resultCount: results.count, searchTimeMs: searchTimeMs)
						}
					}
					.frame(height: 28)
					.background(settings.backgroundColorUI)
				}
			}
			.frame(width: 600, height: windowHeight)
			.background(settings.backgroundColorUI)
			.cornerRadius(DesignTokens.CornerRadius.lg)
			.shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
		}
		.onChange(of: searchText) { newValue in
			performSearch(newValue)
		}
		.onAppear {
			clipboardHistory = clipboardManager.getHistory()
			setupEventMonitor()
			loadAppIcon()
		}
		.onDisappear {
			removeEventMonitor()
		}
		.onReceive(NotificationCenter.default.publisher(for: .showClipboard)) { _ in
			showClipboardHistory()
		}
		.onReceive(NotificationCenter.default.publisher(for: .showLauncher)) { _ in
			isClipboardMode = false
			clipboardHistory = []
			searchText = ""
			selectedIndex = 0
			performSearch("")
		}
		.onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
			onOpenSettings?()
		}
		.onReceive(NotificationCenter.default.publisher(for: .clearIconCache)) { _ in
			IconCache.shared.clear()
			ThumbnailCache.shared.clear()
		}
		.onReceive(NotificationCenter.default.publisher(for: .windowHidden)) { _ in
			resetState()
		}
	}

	private func showClipboardHistory() {
		results = []
		searchText = ""
		selectedIndex = 0

		searchTask?.cancel()

		searchGeneration += 1

		isClipboardMode = true

		clipboardHistory = clipboardManager.getHistory()

		clipboardPage = 0

		let startIndex = 0
		let endIndex = min(clipboardPageSize, clipboardHistory.count)

		if startIndex < clipboardHistory.count {
			let pageItems = Array(clipboardHistory[startIndex ..< endIndex])
			var clipResults = pageItems.enumerated().map { index, entry in
				createClipboardResult(entry: entry, index: startIndex + index)
			}

			if endIndex < clipboardHistory.count {
				clipResults.append(createLoadMoreResult(currentPage: clipboardPage, totalCount: clipboardHistory.count))
			}

			results = clipResults
		} else {
			results = []
		}
	}

	private var showPreview: Bool {
		isClipboardMode && selectedClipboardEntry != nil
	}

	private var selectedResult: CategoryResult? {
		guard selectedIndex < results.count else { return nil }
		return results[selectedIndex]
	}

	private var selectedClipboardEntry: ClipboardEntry? {
		guard isClipboardMode, selectedIndex < clipboardHistory.count else { return nil }
		return clipboardHistory[selectedIndex]
	}

	private func createClipboardResult(entry: ClipboardEntry, index: Int) -> CategoryResult {
		CategoryResult(
			id: "clip-\(entry.timestamp)",
			name: entry.displayName,
			category: "Clipboard",
			path: nil,
			action: { [weak clipboardManager] in
				guard let clipboardManager else { return }
				clipboardManager.moveToTop(at: index)
				NSApp.keyWindow?.orderOut(nil)
			},
			fullContent: entry.content,
			clipboardEntry: entry,
			icon: nil,
			score: 0
		)
	}

	private func createLoadMoreResult(currentPage: Int, totalCount: Int) -> CategoryResult {
		let totalPages = (totalCount + clipboardPageSize - 1) / clipboardPageSize
		let endIndex = min((currentPage + 1) * clipboardPageSize, totalCount)
		let remaining = totalCount - endIndex
		return CategoryResult(
			id: "load-more",
			name: "Page \(currentPage + 1)/\(totalPages) • \(remaining) more",
			category: "Action",
			path: nil,
			action: {
				clipboardPage += 1
				performSearch("")
			},
			fullContent: nil,
			clipboardEntry: nil,
			icon: nil,
			score: 0
		)
	}

	private func performSearch(_ query: String) {
		searchTask?.cancel()
		searchTask = nil

		searchGeneration += 1
		let currentGeneration = searchGeneration

		if isClipboardMode {
			performClipboardSearch(query: query)
			return
		}

		if query.isEmpty {
			performLandingPageSearch()
			return
		}

		performActiveSearch(query: query, generation: currentGeneration)
	}

	private func performClipboardSearch(query: String) {
		let filteredHistory = clipboardHistory

		if query.isEmpty {
			let startIndex = clipboardPage * clipboardPageSize
			let endIndex = min(startIndex + clipboardPageSize, filteredHistory.count)

			guard startIndex < filteredHistory.count else {
				results = []
				return
			}

			let pageItems = Array(filteredHistory[startIndex ..< endIndex])
			var clipResults = pageItems.enumerated().map { index, entry in
				createClipboardResult(entry: entry, index: startIndex + index)
			}

			if endIndex < filteredHistory.count {
				clipResults.append(createLoadMoreResult(
					currentPage: clipboardPage,
					totalCount: filteredHistory.count
				))
			}

			results = clipResults
		} else {
			let lowercaseQuery = query.lowercased()
			let maxItems = settings.maxClipboardItems
			var matchCount = 0
			var filtered: [(Int, ClipboardEntry)] = []
			filtered.reserveCapacity(maxItems)

			for (index, entry) in filteredHistory.enumerated() where matchCount < maxItems {
				if entry.content.lowercased().contains(lowercaseQuery)
					|| entry.displayName.lowercased().contains(lowercaseQuery)
				{
					filtered.append((index, entry))
					matchCount += 1
				}
			}

			results = filtered.map { originalIndex, entry in
				createClipboardResult(entry: entry, index: originalIndex)
			}
		}
		selectedIndex = min(selectedIndex, max(0, results.count - 1))
	}

	private func performLandingPageSearch() {
		settings.cleanInvalidApps()

		var landingResults: [CategoryResult] = []

		let pinnedResults = settings.pinnedApps.map { item in
			let isCommand = item.path.hasPrefix("cmd_")
			return CategoryResult(
				id: item.path,
				name: item.name,
				category: "Pinned",
				path: isCommand ? nil : item.path,
				action: isCommand ? {
					CommandRegistry.shared.executeCommand(id: item.path)
				} : nil,
				fullContent: nil,
				clipboardEntry: nil,
				icon: nil,
				score: 0
			)
		}
		landingResults.append(contentsOf: pinnedResults)

		if settings.showRecentAppsOnLanding {
			let recentResults = settings.recentApps.map { app in
				CategoryResult(
					id: app.path,
					name: app.name,
					category: "Recent",
					path: app.path,
					action: nil,
					fullContent: nil,
					clipboardEntry: nil,
					icon: nil,
					score: 0
				)
			}
			landingResults.append(contentsOf: recentResults)
		}

		if landingResults.isEmpty && !settings.compactMode {
			let emptyIcon = NSImage(systemSymbolName: "square.stack.3d.up.slash", accessibilityDescription: "Empty")
			landingResults.append(
				CategoryResult(
					id: "empty-state",
					name: "No pinned or recently used apps",
					category: "Info",
					path: "Start typing to search for applications",
					action: nil,
					fullContent: nil,
					clipboardEntry: nil,
					icon: emptyIcon,
					score: 0
				))
		}

		results = landingResults
		selectedIndex = 0
	}

	private func performActiveSearch(query: String, generation: Int) {
		let task = DispatchWorkItem { [weak searchEngine] in
			guard let searchEngine else { return }

			guard generation == searchGeneration else {
				return
			}

			let startTime = CFAbsoluteTimeGetCurrent()

			autoreleasepool {
				var allResults: [CategoryResult] = []
				let maxResults = settings.maxResults

				if let calcResult = evaluateCalculator(query) {
					let resultCopy = calcResult
					let expression = query.trimmingCharacters(in: .whitespaces)
					allResults.append(
						CategoryResult(
							id: "calc",
							name: calcResult,
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
						))
				}

				let appResults = searchEngine.search(query, limit: maxResults)
				let fileManager = FileManager.default

				let validAppResults = appResults.filter { result in
					if result.id.hasPrefix("cmd_") {
						return true
					}
					if let path = result.path {
						let exists = fileManager.fileExists(atPath: path)

						if let appDelegate = AppDelegate.shared {
							let wasCachedInvalid = appDelegate.isKnownInvalidApp(path: path)

							if exists, wasCachedInvalid {
								DispatchQueue.main.async {
									appDelegate.markAppAsValid(path: path)
								}
							} else if !exists, !wasCachedInvalid {
								print("Filtering out non-existent app from results: \(result.name) at \(path)")
								DispatchQueue.main.async {
									appDelegate.markAppAsInvalid(path: path)
								}
							} else if !exists {
								return false
							}
						}

						return exists
					}
					return true
				}

				let recentAppsMap = Dictionary(uniqueKeysWithValues: settings.recentApps.enumerated().map {
					($1.path, $0)
				})

				allResults.append(
					contentsOf: validAppResults.map { result in
						let isCommand = result.id.hasPrefix("cmd_")
						var score = result.score

						if let path = result.path, let recentIndex = recentAppsMap[path] {
							score += Int64(10000 - (recentIndex * 100))
						}

						return CategoryResult(
							id: result.id,
							name: result.name,
							category: isCommand ? "Command" : "Applications",
							path: result.path,
							action: isCommand ? {
								CommandRegistry.shared.executeCommand(id: result.id)
							} : nil,
							fullContent: nil,
							clipboardEntry: nil,
							icon: nil,
							score: score
						)
					})

				let actionResults = ActionManager.shared.search(query: query)
				allResults.append(
					contentsOf: actionResults.map { result in
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
					})

				let shouldShowFallback = settings.enableFallbackSearch
					&& query.count >= settings.fallbackSearchMinQueryLength
					&& (settings.fallbackSearchBehavior == .onlyWhenEmpty ? allResults.isEmpty : allResults.count < maxResults)

				if shouldShowFallback {
					let availableSlots = settings.fallbackSearchBehavior == .appendToResults
						? maxResults - allResults.count
						: maxResults
					let maxEngines = min(availableSlots, settings.fallbackSearchMaxEngines)

					for engineId in settings.fallbackSearchEngines.prefix(maxEngines) {
						guard let engine = settings.fallbackEngineById(engineId) else { continue }

						let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
						let searchURL = engine.urlTemplate.replacingOccurrences(of: "{query}", with: encodedQuery)

						var icon: NSImage?
						if engine.iconName.hasPrefix("web:") {
							let iconName = String(engine.iconName.dropFirst(4))
							WebIconDownloader.getIcon(for: iconName, size: NSSize(width: 28, height: 28)) { loadedIcon in
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

						allResults.append(
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
				}

				allResults.sort { $0.score > $1.score }
				allResults = Array(allResults.prefix(maxResults))

				let endTime = CFAbsoluteTimeGetCurrent()
				let elapsedMs = (endTime - startTime) * 1000

				DispatchQueue.main.async {
					guard generation == searchGeneration else {
						return
					}

					autoreleasepool {
						results = allResults
						searchTimeMs = elapsedMs
						if selectedIndex >= allResults.count {
							selectedIndex = 0
						}
					}

					malloc_zone_pressure_relief(nil, 0)
				}
			}
		}

		searchTask = task
		DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05, execute: task)
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
				of: #"\b(USD|EUR|GBP|JPY|CNY|AUD|CAD|CHF|INR|KRW)\b"#, options: .regularExpression
			)
			!= nil
		let hasFunction =
			trimmed.lowercased().contains("sqrt") || trimmed.lowercased().contains("sin")
			|| trimmed.lowercased().contains("cos") || trimmed.lowercased().contains("tan")
			|| trimmed.lowercased().contains("log")

		guard hasNumber, hasMathOp || hasCurrency || hasFunction else { return nil }

		return calculator.evaluate(trimmed)
	}

	private func copyToClipboard(_ text: String) {
		clipboardManager.willCopyToClipboard()

		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(text, forType: .string)

		closeAndReset()
	}

	private func copyImageToClipboard(_ image: NSImage) {
		clipboardManager.willCopyToClipboard()

		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.writeObjects([image])

		closeAndReset()
	}

	private func launchSelected() {
		guard selectedIndex < results.count else { return }
		let result = results[selectedIndex]

		if let action = result.action {
			action()

			if result.id == "load-more" {
				return
			}

			if result.id != "cmd_clipboard" {
				NSApp.keyWindow?.orderOut(nil)
			}
			searchTask?.cancel()
			searchTask = nil
			searchText = ""
			results = []
			if result.id != "cmd_clipboard" {
				clipboardHistory = []
				isClipboardMode = false
			}
			selectedIndex = 0
			return
		}

		if let path = result.path {
			if result.category == "Applications" {
				settings.addRecentApp(name: result.name, path: path)
			}

			NSWorkspace.shared.openApplication(
				at: URL(fileURLWithPath: path),
				configuration: NSWorkspace.OpenConfiguration()
			) { _, error in
				if let error {
					print("Failed to launch: \(error)")
				}
			}

			closeAndReset()
		}
	}

	private func handleEscape() {
		NSApp.keyWindow?.orderOut(nil)
		resetState()
	}

	private func closeAndReset() {
		NSApp.keyWindow?.orderOut(nil)
		searchTask?.cancel()
		searchTask = nil
		searchText = ""
		results = []
		clipboardHistory = []
		isClipboardMode = false
		selectedIndex = 0
		searchTimeMs = nil
	}

	private func resetState() {
		autoreleasepool {
			searchTask?.cancel()
			searchTask = nil
			searchText = ""
			results = []
			clipboardHistory = []
			isClipboardMode = false
			selectedIndex = 0
			clipboardPage = 0
			searchGeneration += 1
			searchTimeMs = nil

			IconCache.shared.clear()
			ThumbnailCache.shared.clear()
		}
	}

	private func handleAltNumber(_ number: Int) {
		let index = number - 1
		guard index >= 0, index < results.count else { return }
		selectedIndex = index
		launchSelected()
	}

	private func handleSaveAsSnippet() {
		guard isClipboardMode, selectedIndex < clipboardHistory.count else { return }
		let entry = clipboardHistory[selectedIndex]

		guard entry.type == .text else { return }

		NotificationCenter.default.post(
			name: .saveClipboardAsSnippet,
			object: nil,
			userInfo: ["content": entry.content]
		)

		NSApp.keyWindow?.orderOut(nil)
	}

	private func handleTogglePin() {
		guard !isClipboardMode, selectedIndex < results.count else { return }
		let result = results[selectedIndex]

		let isApp = result.category == "Applications" || result.category == "Pinned" || result.category == "Recent"
		let isCommand = result.category == "Command"

		guard isApp || isCommand else { return }

		let identifier: String
		if isCommand {
			identifier = result.id
		} else {
			guard let path = result.path else { return }
			identifier = path
		}

		if settings.pinnedApps.contains(where: { $0.path == identifier }) {
			settings.pinnedApps.removeAll { $0.path == identifier }
		} else {
			let pinnedItem = RecentApp(name: result.name, path: identifier, timestamp: Date().timeIntervalSince1970)
			settings.pinnedApps.append(pinnedItem)
		}
		settings.save()
		performSearch(searchText)
	}

	private func handleShowInFinder() {
		guard !isClipboardMode, selectedIndex < results.count else { return }
		let result = results[selectedIndex]

		let isApp = result.category == "Applications" || result.category == "Pinned" || result.category == "Recent"
		guard isApp, let path = result.path else { return }

		NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
	}

	private func handleGetInfo() {
		guard !isClipboardMode, selectedIndex < results.count else { return }
		let result = results[selectedIndex]

		let isApp = result.category == "Applications" || result.category == "Pinned" || result.category == "Recent"
		guard isApp, let path = result.path else { return }

		let fileManager = FileManager.default
		var totalSize: UInt64 = 0

		if let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) {
			for case let fileURL as URL in enumerator {
				if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
				   let isRegularFile = resourceValues.isRegularFile,
				   isRegularFile,
				   let fileSize = resourceValues.fileSize
				{
					totalSize += UInt64(fileSize)
				}
			}
		}

		let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)

		var version: String?
		if let bundle = Bundle(path: path),
		   let ver = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
		{
			version = ver
		}

		selectedAppInfo = AppInfo(name: result.name, path: path, size: sizeStr, version: version)
	}

	private func handleCopyPath() {
		guard !isClipboardMode, selectedIndex < results.count else { return }
		let result = results[selectedIndex]

		let isApp = result.category == "Applications" || result.category == "Pinned" || result.category == "Recent"
		guard isApp, let path = result.path else { return }

		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(path, forType: .string)
	}

	private func handleQuitApp() {
		guard !isClipboardMode, selectedIndex < results.count else { return }
		let result = results[selectedIndex]

		let isApp = result.category == "Applications" || result.category == "Pinned" || result.category == "Recent"
		guard isApp, let path = result.path else { return }

		if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL?.path == path }) {
			app.terminate()
		}
	}

	private func handleHideApp() {
		guard !isClipboardMode, selectedIndex < results.count else { return }
		let result = results[selectedIndex]

		let isApp = result.category == "Applications" || result.category == "Pinned" || result.category == "Recent"
		guard isApp, let path = result.path else { return }

		if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL?.path == path }) {
			app.hide()
		}
	}

	private func loadAppIcon() {
		if let icon = NSImage(named: "AppIcon") {
			appIcon = icon
		} else {
			appIcon = NSImage(systemSymbolName: "app.badge", accessibilityDescription: "Summon")
		}
	}

	private func handleSaveImage() {
		guard isClipboardMode, selectedIndex < clipboardHistory.count else { return }
		let entry = clipboardHistory[selectedIndex]

		guard entry.type == .image, let imagePath = entry.imageFilePath else { return }

		let saveDirectory: URL
		if !settings.imageSavePath.isEmpty, FileManager.default.fileExists(atPath: settings.imageSavePath) {
			saveDirectory = URL(fileURLWithPath: settings.imageSavePath)
		} else {
			saveDirectory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
		}

		let timestamp = Int(Date().timeIntervalSince1970)
		let fileName = "Screenshot_\(timestamp).png"
		let fileURL = saveDirectory.appendingPathComponent(fileName)

		do {
			let sourceURL = URL(fileURLWithPath: imagePath)
			try FileManager.default.copyItem(at: sourceURL, to: fileURL)
			NSWorkspace.shared.activateFileViewerSelecting([fileURL])
		} catch {
			print("Failed to save image: \(error)")
		}

		NSApp.keyWindow?.orderOut(nil)
	}

	private func matchesShortcut(_ event: NSEvent, _ shortcut: KeyboardShortcut) -> Bool {
		guard event.keyCode == UInt16(shortcut.keyCode) else { return false }

		let flags = event.modifierFlags
		let hasCmd = flags.contains(.command)
		let hasOpt = flags.contains(.option)
		let hasShift = flags.contains(.shift)
		let hasCtrl = flags.contains(.control)

		let wantsCmd = shortcut.modifiers & UInt32(cmdKey) != 0
		let wantsOpt = shortcut.modifiers & UInt32(optionKey) != 0
		let wantsShift = shortcut.modifiers & UInt32(shiftKey) != 0
		let wantsCtrl = shortcut.modifiers & UInt32(controlKey) != 0

		return hasCmd == wantsCmd && hasOpt == wantsOpt && hasShift == wantsShift && hasCtrl == wantsCtrl
	}

	private func setupEventMonitor() {
		eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [self] event in
			if event.type == .flagsChanged {
				let optionPressed = event.modifierFlags.contains(.option)
				if showSecondaryHints != optionPressed {
					showSecondaryHints = optionPressed
				}
				return event
			}

			if let keyWindow = NSApp.keyWindow,
			   keyWindow.title == "Settings"
			   || keyWindow.contentView?.subviews.first(where: {
			   	String(describing: type(of: $0)).contains("SettingsView")
			   }) != nil
			{
				return event
			}

			// Clipboard mode shortcuts
			if isClipboardMode {
				if matchesShortcut(event, settings.saveClipboardShortcut) {
					if selectedIndex < clipboardHistory.count {
						let entry = clipboardHistory[selectedIndex]
						if entry.type == .text {
							handleSaveAsSnippet()
						} else if entry.type == .image {
							handleSaveImage()
						}
					}
					return nil
				}
			}

			// App action shortcuts
			if !isClipboardMode {
				if matchesShortcut(event, settings.pinAppShortcut) {
					handleTogglePin()
					return nil
				} else if matchesShortcut(event, settings.revealAppShortcut) {
					handleShowInFinder()
					return nil
				} else if matchesShortcut(event, settings.copyPathShortcut) {
					handleCopyPath()
					return nil
				} else if matchesShortcut(event, settings.quitAppShortcut) {
					handleQuitApp()
					return nil
				} else if matchesShortcut(event, settings.hideAppShortcut) {
					handleHideApp()
					return nil
				}
			}

			if let char = event.charactersIgnoringModifiers?.first,
			   let digit = char.wholeNumberValue,
			   digit >= 1, digit <= 9
			{
				let flags = event.modifierFlags
				let shouldTrigger: Bool =
					switch settings.quickSelectModifier {
					case .option:
						flags.contains(.option)
					case .command:
						flags.contains(.command)
					case .control:
						flags.contains(.control)
					}

				if shouldTrigger {
					handleAltNumber(digit)
					return nil
				}
			}
			return event
		}
	}

	private func removeEventMonitor() {
		if let monitor = eventMonitor {
			NSEvent.removeMonitor(monitor)
			eventMonitor = nil
		}
	}
}

extension SearchEngine: ObservableObject {}
