import Carbon
import SwiftUI

// swiftlint:disable:next avoid_stateobject_in_child
struct ContentView: View {
	@ObservedObject var searchEngine: SearchEngine
	@EnvironmentObject var settings: AppSettings
	let clipboardManager: ClipboardManager
	@ObservedObject var calculator: Calculator

	@StateObject var searchCoordinator: SearchCoordinator
	@StateObject var clipboardCoordinator: ClipboardCoordinator
	@StateObject var notesCoordinator: NotesCoordinator

	init(searchEngine: SearchEngine, clipboardManager: ClipboardManager) {
		self.searchEngine = searchEngine
		self.clipboardManager = clipboardManager
		let sharedCalculator = Calculator()
		calculator = sharedCalculator

		_searchCoordinator = StateObject(
			wrappedValue: SearchCoordinator(
				searchEngine: searchEngine,
				settings: AppSettings.shared,
				calculator: sharedCalculator
			))
		_clipboardCoordinator = StateObject(
			wrappedValue: ClipboardCoordinator(
				clipboardManager: clipboardManager,
				settings: AppSettings.shared
			))
		_notesCoordinator = StateObject(
			wrappedValue: NotesCoordinator(
				settings: AppSettings.shared
			))
	}

	@State var searchText = ""
	@State var selectedIndex = 0
	@State var isClipboardMode = false
	@State var isNotesMode = false
	@State private var lastMousePosition: CGPoint?
	@State private var hoveredIndex: Int?
	@State private var mouseMovedMonitor: Any?
	@State var historyNavigationIndex: Int?
	@State var historyQueries: [String] = []
	@State var currentEditedQuery = ""

	var results: [CategoryResult] {
		if isNotesMode {
			return notesResults
		} else if isClipboardMode {
			return clipboardResults
		} else {
			return searchCoordinator.results
		}
	}

	var clipboardHistory: [ClipboardEntry] {
		clipboardCoordinator.clipboardHistory
	}

	@State var clipboardResults: [CategoryResult] = []
	@State var notesResults: [CategoryResult] = []
	@State private var cachedLandingResults: [CategoryResult] = []
	@State private var landingCacheKey: String = ""

	var windowHeight: CGFloat {
		let maxVisibleRows = 7
		let actualRows = min(results.count, maxVisibleRows)
		let footerHeight: CGFloat = shouldShowFooter ? DesignTokens.Layout.footerHeight : 0

		let topPadding: CGFloat = DesignTokens.Spacing.xs
		let bottomBuffer: CGFloat = DesignTokens.Spacing.xxs

		let hasDictionaryResult = results.first?.category == "Dictionary" || results.first?.category == "DictionaryNotFound"

		if isClipboardMode {
			return DesignTokens.Layout.searchBarHeight + DesignTokens.Layout.dividerHeight + topPadding
				+ CGFloat(maxVisibleRows) * DesignTokens.Layout.resultRowHeight
				+ bottomBuffer + footerHeight
		}

		if settings.compactMode {
			guard actualRows > 0 else {
				return DesignTokens.Layout.searchBarHeight
			}

			if hasDictionaryResult, let firstResult = results.first {
				let baseHeight = DesignTokens.Layout.searchBarHeight + DesignTokens.Layout.dividerHeight + topPadding + bottomBuffer + footerHeight
				let definitionHeight = estimateDictionaryHeight(firstResult)
				return baseHeight + definitionHeight
			}

			return DesignTokens.Layout.searchBarHeight + DesignTokens.Layout.dividerHeight + topPadding
				+ CGFloat(actualRows) * DesignTokens.Layout.resultRowHeight
				+ bottomBuffer + footerHeight
		}

		return DesignTokens.Layout.searchBarHeight + DesignTokens.Layout.dividerHeight + topPadding
			+ CGFloat(maxVisibleRows) * DesignTokens.Layout.resultRowHeight
			+ bottomBuffer + footerHeight
	}

	private func estimateDictionaryHeight(_ result: CategoryResult) -> CGFloat {
		let wordHeight: CGFloat = 28
		let padding: CGFloat = DesignTokens.Spacing.xs * 2

		guard let definition = result.path else {
			return wordHeight + padding
		}

		let parts = definition.components(separatedBy: CharacterSet(charactersIn: ".;"))
		let meaningfulParts = parts.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).count > 10 }

		let maxDefinitions = 3
		let actualDefinitions = min(meaningfulParts.count, maxDefinitions)

		let posHeaderHeight: CGFloat = 16
		let definitionLineHeight: CGFloat = 18

		return wordHeight + posHeaderHeight + CGFloat(actualDefinitions) * definitionLineHeight + padding
	}

	var shouldShowFooter: Bool {
		guard settings.showFooterHints else { return false }

		if isClipboardMode {
			return !results.isEmpty && selectedIndex < clipboardHistory.count
		}

		if !settings.compactMode {
			return true
		}

		guard !results.isEmpty, selectedIndex < results.count else { return false }

		let selectedResult = results[selectedIndex]
		let isRelevant = ["Applications", "Pinned", "Recent", "Command", "Action", "Web", "Dictionary", "DictionaryNotFound"]
			.contains(selectedResult.category)

		return isRelevant
	}

	@State var eventMonitor: Any?
	@State var selectedAppInfo: AppInfo?
	@State var showSecondaryHints = false
	@State var appIcon: NSImage?
	var onOpenSettings: (() -> Void)?

	struct AppInfo {
		let name: String
		let path: String
		let size: String
		let version: String?
	}

	func isAppRunning(path: String) -> Bool {
		NSWorkspace.shared.runningApplications.contains { app in
			app.bundleURL?.path == path
		}
	}

	func getAppHints(for result: CategoryResult, identifier: String) -> [HintAction] {
		let isCommand = result.category == "Command"
		let isPinned = settings.pinnedApps.contains { $0.path == identifier }

		if isCommand {
			return [
				HintAction(
					shortcut: settings.pinAppShortcut.displayString,
					label: isPinned ? "Unpin" : "Pin",
					action: { self.handleTogglePin() }
				)
			]
		}

		let running = isAppRunning(path: identifier)

		if showSecondaryHints {
			var hints: [HintAction] = [
				HintAction(
					shortcut: settings.copyPathShortcut.displayString,
					label: "Copy Path",
					action: { self.handleCopyPath() }
				)
			]
			if running {
				hints.insert(
					HintAction(
						shortcut: settings.quitAppShortcut.displayString,
						label: "Quit App",
						action: { self.handleQuitApp(force: false) }
					),
					at: 0
				)
				hints.insert(
					HintAction(
						shortcut: settings.hideAppShortcut.displayString,
						label: "Hide App",
						action: { self.handleHideApp() }
					),
					at: 1
				)
			}
			return hints
		} else {
			var hints: [HintAction] = []
			if running {
				hints.append(
					HintAction(
						shortcut: settings.quitAppShortcut.displayString,
						label: "Quit",
						action: { self.handleQuitApp(force: false) }
					))
				hints.append(
					HintAction(
						shortcut: settings.hideAppShortcut.displayString,
						label: "Hide",
						action: { self.handleHideApp() }
					))
			}
			hints.append(
				HintAction(
					shortcut: settings.pinAppShortcut.displayString,
					label: isPinned ? "Unpin" : "Pin",
					action: { self.handleTogglePin() }
				))
			if !running {
				hints.append(
					HintAction(
						shortcut: settings.revealAppShortcut.displayString,
						label: "Reveal",
						action: { self.handleShowInFinder() }
					))
			}
			return hints
		}
	}

	var placeholderText: String {
		isClipboardMode ? "Type to filter entries..." : "Search applications..."
	}

	func getClipboardHints() -> [HintAction] {
		guard isClipboardMode, selectedIndex < clipboardHistory.count else { return [] }

		let entry = clipboardHistory[selectedIndex]
		var hints: [HintAction] = []

		if entry.type == .text {
			hints.append(HintAction(
				shortcut: settings.saveClipboardShortcut.displayString,
				label: "Save as text expansion",
				action: { self.handleSaveAsSnippet() }
			))
		} else if entry.type == .image {
			hints.append(HintAction(
				shortcut: settings.saveClipboardShortcut.displayString,
				label: "Save to Pictures",
				action: { self.handleSaveImage() }
			))
		}

		hints.append(HintAction(
			shortcut: settings.deleteClipboardShortcut.displayString,
			label: "Delete",
			action: { self.handleDeleteClipboardEntry() }
		))

		return hints
	}

	var body: some View {
		ZStack {
			if notesCoordinator.editingNote != nil || notesCoordinator.isCreatingNew {
				Color.black.opacity(0.4)
					.ignoresSafeArea()
					.onTapGesture {
						notesCoordinator.editingNote = nil
						notesCoordinator.isCreatingNew = false
					}

				NoteEditorView(
					coordinator: notesCoordinator,
					isPresented: Binding(
						get: { notesCoordinator.editingNote != nil || notesCoordinator.isCreatingNew },
						set: { if !$0 {
							notesCoordinator.editingNote = nil
							notesCoordinator.isCreatingNew = false
						}}
					)
				)
				.environmentObject(settings)
			}

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
							handleUpArrow()
						},
						onDownArrow: {
							handleDownArrow()
						},
						onAltNumber: { number in
							handleAltNumber(number)
						}
					)
					.frame(height: 36, alignment: .leading)
				}
				.padding(.horizontal, DesignTokens.Spacing.lg)
				.padding(.vertical, DesignTokens.Spacing.md)
				.frame(height: DesignTokens.Layout.searchBarHeight)
				.background(settings.backgroundColorUI)
				.zIndex(1000)

				if !results.isEmpty || !settings.compactMode {
					Divider()
						.opacity(0.5)
				}

				ZStack {
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
													hoveredIndex = index
													handleMouseHover(index: index)
												} else if hoveredIndex == index {
													hoveredIndex = nil
												}
											}
										}
										.padding(.top, 4)
									}
									.onChange(of: selectedIndex) { newIndex in
										proxy.scrollTo(newIndex, anchor: .center)
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
					} else if !searchText.isEmpty, !isClipboardMode, !searchCoordinator.isSearching,
					          !settings.compactMode
					{
						EmptyStateView(
							iconName: "magnifyingglass",
							title: "No results",
							subtitle: nil,
							height: DesignTokens.Layout.defaultListHeight
						)
						.equatable()
						.background(settings.backgroundColorUI)
					} else if searchText.isEmpty, !isClipboardMode, !settings.compactMode {
						EmptyStateView(
							iconName: "square.stack.3d.up.slash",
							title: "No pinned or recently launched apps",
							subtitle: "Start typing to search",
							height: DesignTokens.Layout.defaultListHeight
						)
						.equatable()
						.background(settings.backgroundColorUI)
					} else if !searchText.isEmpty, !isClipboardMode, searchCoordinator.isSearching,
					          !settings.compactMode
					{
						Spacer()
							.frame(height: DesignTokens.Layout.defaultListHeight)
							.background(settings.backgroundColorUI)
					} else if isClipboardMode, results.isEmpty {
						EmptyStateView(
							iconName: "doc.on.clipboard",
							title: "No clipboard items",
							subtitle: nil,
							height: DesignTokens.Layout.defaultListHeight
						)
						.equatable()
						.background(settings.backgroundColorUI)
					} else if settings.compactMode, results.isEmpty {
						Color.clear
							.frame(height: 0)
					}
				}
				.frame(height: settings.compactMode ? nil : DesignTokens.Layout.defaultListHeight)

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

						if isClipboardMode {
							let hints = getClipboardHints()
							if !hints.isEmpty {
								ContextualHints(hints: hints)
							}
						} else if !isClipboardMode, selectedIndex < results.count {
							let selectedResult = results[selectedIndex]
							let isDictionary = selectedResult.category == "Dictionary"
							let isDictionaryNotFound = selectedResult.category == "DictionaryNotFound"
							let isApp =
								selectedResult.category == "Applications"
									|| selectedResult.category == "Pinned"
									|| selectedResult.category == "Recent"
							let isCommand = selectedResult.category == "Command"
							let isAction =
								selectedResult.category == "Action"
									|| selectedResult.category == "Web"

							if isDictionary {
								ContextualHints(hints: [HintAction(shortcut: "↩", label: "Copy definition")])
							} else if isDictionaryNotFound {
								Text("No definition found")
									.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
									.foregroundColor(settings.secondaryTextColorUI)
							} else if isApp {
								if let appInfo = selectedAppInfo {
									AppInfoDisplay(info: appInfo)
								} else if let path = selectedResult.path {
									ContextualHints(
										hints: getAppHints(for: selectedResult, identifier: path))
								}
							} else if isCommand || isAction {
								let hints =
									isCommand
										? getAppHints(
											for: selectedResult, identifier: selectedResult.id
										)
										: [HintAction(shortcut: "↩", label: "Open")]
								ContextualHints(hints: hints)
							}
						}

						Spacer()

						if !isClipboardMode, let searchTimeMs = searchCoordinator.searchTimeMs {
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
			if historyNavigationIndex == nil {
				historyQueries = []
				currentEditedQuery = ""
			}
			performSearch(newValue)
		}
		.onChange(of: results.count) { count in
			if selectedIndex >= count {
				selectedIndex = 0
			}
		}
		.onAppear {
			clipboardCoordinator.loadHistory()
			setupEventMonitor()
			setupMouseMovedMonitor()
			loadAppIcon()
			if searchText.isEmpty, !isClipboardMode {
				performLandingPageSearch()
			}
		}
		.onDisappear {
			removeEventMonitor()
			removeMouseMovedMonitor()
		}
		.onReceive(NotificationCenter.default.publisher(for: .showClipboard)) { _ in
			showClipboardHistory()
		}
		.onReceive(NotificationCenter.default.publisher(for: .showLauncher)) { _ in
			isClipboardMode = false
			isNotesMode = false
			searchText = ""
			selectedIndex = 0
			lastMousePosition = nil
			performLandingPageSearch()
		}
		.onReceive(NotificationCenter.default.publisher(for: .showNotes)) { _ in
			showNotes()
		}
		.onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
			onOpenSettings?()
		}
		.onReceive(NotificationCenter.default.publisher(for: .clearIconCache)) { _ in
			ImageCache.icon.clear()
			ImageCache.thumbnail.clear()
		}
		.onReceive(NotificationCenter.default.publisher(for: .windowHidden)) { _ in
			resetState()
		}
	}

	func showClipboardHistory() {
		searchText = ""
		selectedIndex = 0
		isClipboardMode = true
		isNotesMode = false
		lastMousePosition = nil
		clipboardCoordinator.loadHistory()
		clipboardCoordinator.resetToFirstPage()
		clipboardResults = clipboardCoordinator.createClipboardResults(searchQuery: "")
	}

	func showNotes() {
		searchText = ""
		selectedIndex = 0
		isClipboardMode = false
		isNotesMode = true
		lastMousePosition = nil
		notesCoordinator.loadNotes()
		notesResults = notesCoordinator.searchNotes(query: "")
	}

	var showPreview: Bool { isClipboardMode && selectedClipboardEntry != nil }

	var selectedResult: CategoryResult? {
		guard selectedIndex < results.count else { return nil }
		return results[selectedIndex]
	}

	var selectedClipboardEntry: ClipboardEntry? {
		guard isClipboardMode, selectedIndex < clipboardHistory.count else { return nil }
		return clipboardHistory[selectedIndex]
	}

	func performSearch(_ query: String) {
		if isNotesMode {
			notesResults = notesCoordinator.searchNotes(query: query)
			selectedIndex = 0
			return
		}
		if isClipboardMode {
			clipboardResults = clipboardCoordinator.createClipboardResults(searchQuery: query)
			selectedIndex = 0
			return
		}
		if query.isEmpty { performLandingPageSearch(); return }
		searchCoordinator.performSearch(query)
		selectedIndex = 0
	}

	func performLandingPageSearch() {
		settings.cleanInvalidApps()

		let currentKey = "\(settings.pinnedApps.count):\(settings.recentApps.count):\(settings.showRecentAppsOnLanding)"
		if landingCacheKey == currentKey, !cachedLandingResults.isEmpty {
			searchCoordinator.results = cachedLandingResults
			selectedIndex = 0
			return
		}

		var landingResults: [CategoryResult] = []

		landingResults.append(
			contentsOf: settings.pinnedApps.map { item in
				let isCommand = item.path.hasPrefix("cmd_")
				return CategoryResult(
					id: item.path,
					name: item.name,
					category: "Pinned",
					path: isCommand ? nil : item.path,
					action: isCommand
						? { CommandRegistry.shared.executeCommand(id: item.path) }
						: nil,
					fullContent: nil,
					clipboardEntry: nil,
					icon: nil,
					score: 0
				)
			})

		if settings.showRecentAppsOnLanding {
			landingResults.append(
				contentsOf: settings.recentApps.map { app in
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
				})
		}

		cachedLandingResults = landingResults
		landingCacheKey = currentKey
		searchCoordinator.results = landingResults
		selectedIndex = 0
	}

	func copyToClipboard(_ text: String) {
		clipboardManager.willCopyToClipboard()
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(text, forType: .string)
		closeAndReset()
	}

	func copyImageToClipboard(_ image: NSImage) {
		clipboardManager.willCopyToClipboard()
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.writeObjects([image])
		closeAndReset()
	}

	func launchSelected() {
		guard selectedIndex < results.count else { return }
		let result = results[selectedIndex]
		if !isClipboardMode, !searchText.isEmpty { QueryHistoryManager.shared.addQuery(searchText) }

		if let action = result.action {
			action()
			guard result.id != "load_more" else {
				clipboardCoordinator.loadNextPage()
				clipboardResults = clipboardCoordinator.createClipboardResults(searchQuery: searchText)
				return
			}
			guard result.id == "cmd_clipboard" else { closeAndReset(); return }
			selectedIndex = 0
			return
		}

		if let path = result.path {
			if result.category == "Applications" { settings.addRecentApp(name: result.name, path: path) }
			NSWorkspace.shared.openApplication(
				at: URL(fileURLWithPath: path), configuration: NSWorkspace.OpenConfiguration()
			) { _, error in if let error { print("Failed to launch: \(error)") } }
			closeAndReset()
		}
	}

	func handleEscape() { NSApp.keyWindow?.orderOut(nil); resetState() }

	func closeAndReset() {
		NSApp.keyWindow?.orderOut(nil)
		searchCoordinator.cancelSearch()
		searchText = ""
		isClipboardMode = false
		isNotesMode = false
		selectedIndex = 0
		lastMousePosition = nil
	}

	func setupMouseMovedMonitor() {
		mouseMovedMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
			guard let hovered = self.hoveredIndex else { return event }
			let mouseLocation = NSEvent.mouseLocation
			if let lastPosition = self.lastMousePosition {
				let dx = mouseLocation.x - lastPosition.x, dy = mouseLocation.y - lastPosition.y
				if dx * dx + dy * dy > 9.0 {
					self.selectedIndex = hovered
					self.lastMousePosition = mouseLocation
				}
			} else { self.lastMousePosition = mouseLocation }
			return event
		}
	}

	func removeMouseMovedMonitor() {
		if let monitor = mouseMovedMonitor { NSEvent.removeMonitor(monitor); mouseMovedMonitor = nil }
	}

	func handleMouseHover(index: Int) {
		guard hoveredIndex != index else { return }
		let mouseLocation = NSEvent.mouseLocation
		if let lastPosition = lastMousePosition {
			let dx = mouseLocation.x - lastPosition.x, dy = mouseLocation.y - lastPosition.y
			if dx * dx + dy * dy > 9.0 {
				selectedIndex = index
				lastMousePosition = mouseLocation
			}
		} else { lastMousePosition = mouseLocation }
	}

	func resetState() {
		autoreleasepool {
			searchCoordinator.resetResults()
			clipboardResults = []
			notesResults = []
			searchText = ""
			isClipboardMode = false
			isNotesMode = false
			selectedIndex = 0
			lastMousePosition = nil
			historyNavigationIndex = nil
			currentEditedQuery = ""

			ImageCache.icon.clear()
			ImageCache.thumbnail.clear()
		}
	}
}

struct EmptyStateView: View, Equatable {
	let iconName: String
	let title: String
	let subtitle: String?
	let height: CGFloat

	var body: some View {
		VStack {
			Spacer()
			VStack(spacing: DesignTokens.Spacing.md) {
				Image(systemName: iconName)
					.font(.system(size: 48))
					.foregroundColor(.secondary.opacity(0.5))
				Text(title)
					.font(.system(size: 15))
					.foregroundColor(.secondary)
				if let subtitle {
					Text(subtitle)
						.font(.system(size: 13))
						.foregroundColor(.secondary.opacity(0.7))
				}
			}
			Spacer()
		}
		.frame(height: height)
	}

	static func == (lhs: EmptyStateView, rhs: EmptyStateView) -> Bool {
		lhs.iconName == rhs.iconName &&
		lhs.title == rhs.title &&
		lhs.subtitle == rhs.subtitle &&
		lhs.height == rhs.height
	}
}

extension SearchEngine: ObservableObject {}
