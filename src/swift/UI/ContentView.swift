import Carbon
import SwiftUI

// swiftlint:disable:next avoid_stateobject_in_child type_body_length
struct ContentView: View {
    @ObservedObject var searchEngine: SearchEngine
    @ObservedObject var settings = AppSettings.shared
    let clipboardManager: ClipboardManager
    @ObservedObject var calculator: Calculator

    @StateObject private var searchCoordinator: SearchCoordinator
    @StateObject private var clipboardCoordinator: ClipboardCoordinator

    init(searchEngine: SearchEngine, clipboardManager: ClipboardManager) {
        self.searchEngine = searchEngine
        self.clipboardManager = clipboardManager
        calculator = Calculator()

        _searchCoordinator = StateObject(
            wrappedValue: SearchCoordinator(
                searchEngine: searchEngine,
                settings: AppSettings.shared,
                calculator: Calculator()
            ))
        _clipboardCoordinator = StateObject(
            wrappedValue: ClipboardCoordinator(
                clipboardManager: clipboardManager,
                settings: AppSettings.shared
            ))
    }

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var isClipboardMode = false

    private var results: [CategoryResult] {
        isClipboardMode ? clipboardResults : searchCoordinator.results
    }

    private var clipboardHistory: [ClipboardEntry] {
        clipboardCoordinator.clipboardHistory
    }

    @State private var clipboardResults: [CategoryResult] = []

    private var windowHeight: CGFloat {
        let maxVisibleRows = 7
        let actualRows = min(results.count, maxVisibleRows)
        let footerHeight: CGFloat = shouldShowFooter ? 32 : 0

        let searchBarHeight: CGFloat = 52
        let dividerHeight: CGFloat = 1
        let topPadding: CGFloat = 4
        let rowHeight: CGFloat = 44
        let bottomBuffer: CGFloat = 1

        if settings.compactMode && !isClipboardMode {
            guard actualRows > 0 else { return searchBarHeight }
            return searchBarHeight + dividerHeight + topPadding + CGFloat(actualRows) * rowHeight
                + bottomBuffer + footerHeight
        }

        return searchBarHeight + dividerHeight + topPadding + CGFloat(maxVisibleRows) * rowHeight
            + bottomBuffer + footerHeight
    }

    private var shouldShowFooter: Bool {
        guard settings.showFooterHints else { return false }

        if !settings.compactMode {
            return true
        }

        if isClipboardMode {
            return !results.isEmpty && selectedIndex < clipboardHistory.count
        }

        guard !results.isEmpty, selectedIndex < results.count else { return false }

        let selectedResult = results[selectedIndex]
        let isRelevant = ["Applications", "Pinned", "Recent", "Command", "Action", "Web"]
            .contains(selectedResult.category)

        return isRelevant
    }

    @State private var eventMonitor: Any?
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
            return [
                HintAction(
                    shortcut: settings.pinAppShortcut.displayString,
                    label: isPinned ? "Unpin" : "Pin")
            ]
        }

        let running = isAppRunning(path: identifier)

        if showSecondaryHints {
            var hints: [HintAction] = [
                HintAction(shortcut: settings.copyPathShortcut.displayString, label: "Copy Path")
            ]
            if running {
                hints.insert(
                    HintAction(shortcut: settings.quitAppShortcut.displayString, label: "Quit App"),
                    at: 0)
                hints.insert(
                    HintAction(shortcut: settings.hideAppShortcut.displayString, label: "Hide App"),
                    at: 1)
            }
            return hints
        } else {
            var hints: [HintAction] = []
            if running {
                hints.append(
                    HintAction(shortcut: settings.quitAppShortcut.displayString, label: "Quit"))
                hints.append(
                    HintAction(shortcut: settings.hideAppShortcut.displayString, label: "Hide"))
            }
            hints.append(
                HintAction(
                    shortcut: settings.pinAppShortcut.displayString,
                    label: isPinned ? "Unpin" : "Pin"))
            if !running {
                hints.append(
                    HintAction(shortcut: settings.revealAppShortcut.displayString, label: "Reveal"))
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
                                    HintAction(
                                        shortcut: settings.saveClipboardShortcut.displayString,
                                        label: "Save as text expansion")
                                ])
                            } else if entry.type == .image {
                                ContextualHints(hints: [
                                    HintAction(
                                        shortcut: settings.saveClipboardShortcut.displayString,
                                        label: "Save to Pictures")
                                ])
                            }
                        } else if !isClipboardMode, selectedIndex < results.count {
                            let selectedResult = results[selectedIndex]
                            let isApp =
                                selectedResult.category == "Applications"
                                || selectedResult.category == "Pinned"
                                || selectedResult.category == "Recent"
                            let isCommand = selectedResult.category == "Command"
                            let isAction =
                                selectedResult.category == "Action"
                                || selectedResult.category == "Web"

                            if isApp {
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
                                        for: selectedResult, identifier: selectedResult.id)
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
            performSearch(newValue)
        }
        .onAppear {
            clipboardCoordinator.loadHistory()
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
            searchText = ""
            selectedIndex = 0
            searchCoordinator.resetResults()
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
        searchText = ""
        selectedIndex = 0
        isClipboardMode = true

        clipboardCoordinator.loadHistory()
        clipboardCoordinator.resetToFirstPage()
        clipboardResults = clipboardCoordinator.createClipboardResults(searchQuery: "")
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

    private func performSearch(_ query: String) {
        if isClipboardMode {
            clipboardResults = clipboardCoordinator.createClipboardResults(searchQuery: query)
            selectedIndex = min(selectedIndex, max(0, clipboardResults.count - 1))
            return
        }

        if query.isEmpty {
            performLandingPageSearch()
            return
        }

        searchCoordinator.performSearch(query)
        selectedIndex = min(selectedIndex, max(0, searchCoordinator.results.count - 1))
    }

    private func performLandingPageSearch() {
        settings.cleanInvalidApps()

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

        if landingResults.isEmpty && !settings.compactMode {
            landingResults.append(
                CategoryResult(
                    id: "empty-state",
                    name: "No pinned or recently used apps",
                    category: "Info",
                    path: "Start typing to search for applications",
                    action: nil,
                    fullContent: nil,
                    clipboardEntry: nil,
                    icon: NSImage(
                        systemSymbolName: "square.stack.3d.up.slash",
                        accessibilityDescription: "Empty"),
                    score: 0
                ))
        }

        searchCoordinator.results = landingResults
        selectedIndex = 0
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

            guard result.id != "load_more" else {
                clipboardCoordinator.loadNextPage()
                clipboardResults = clipboardCoordinator.createClipboardResults(
                    searchQuery: searchText)
                return
            }

            guard result.id == "cmd_clipboard" else {
                closeAndReset()
                return
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
        searchCoordinator.cancelSearch()
        searchText = ""
        isClipboardMode = false
        selectedIndex = 0
    }

    private func resetState() {
        autoreleasepool {
            searchCoordinator.resetResults()
            clipboardResults = []
            searchText = ""
            isClipboardMode = false
            selectedIndex = 0

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

        let isApp =
            result.category == "Applications" || result.category == "Pinned"
            || result.category == "Recent"
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
            settings.pinnedApps.removeAll(where: { $0.path == identifier })
        } else {
            settings.pinnedApps.append(
                RecentApp(
                    name: result.name, path: identifier, timestamp: Date().timeIntervalSince1970))
        }
        settings.save()
        performSearch(searchText)
    }

    private func handleShowInFinder() {
        guard !isClipboardMode, selectedIndex < results.count else { return }
        let result = results[selectedIndex]

        let isApp =
            result.category == "Applications" || result.category == "Pinned"
            || result.category == "Recent"
        guard isApp, let path = result.path else { return }

        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    private func handleGetInfo() {
        guard !isClipboardMode, selectedIndex < results.count else { return }
        let result = results[selectedIndex]

        let isApp =
            result.category == "Applications" || result.category == "Pinned"
            || result.category == "Recent"
        guard isApp, let path = result.path else { return }

        let fileManager = FileManager.default
        var totalSize: UInt64 = 0

        if let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])
        {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [
                    .fileSizeKey, .isRegularFileKey,
                ]),
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

        let isApp =
            result.category == "Applications" || result.category == "Pinned"
            || result.category == "Recent"
        guard isApp, let path = result.path else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
    }

    private func handleQuitApp() {
        guard !isClipboardMode, selectedIndex < results.count else { return }
        let result = results[selectedIndex]

        let isApp =
            result.category == "Applications" || result.category == "Pinned"
            || result.category == "Recent"
        guard isApp, let path = result.path else { return }

        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleURL?.path == path
        }) {
            app.terminate()
        }
    }

    private func handleHideApp() {
        guard !isClipboardMode, selectedIndex < results.count else { return }
        let result = results[selectedIndex]

        let isApp =
            result.category == "Applications" || result.category == "Pinned"
            || result.category == "Recent"
        guard isApp, let path = result.path else { return }

        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleURL?.path == path
        }) {
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
        if !settings.imageSavePath.isEmpty,
            FileManager.default.fileExists(atPath: settings.imageSavePath)
        {
            saveDirectory = URL(fileURLWithPath: settings.imageSavePath)
        } else {
            saveDirectory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)
                .first!
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

        return hasCmd == wantsCmd && hasOpt == wantsOpt && hasShift == wantsShift
            && hasCtrl == wantsCtrl
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) {
            [self] event in
            self.handleKeyEvent(event)
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        if event.type == .flagsChanged {
            let optionPressed = event.modifierFlags.contains(.option)
            if showSecondaryHints != optionPressed {
                showSecondaryHints = optionPressed
            }
            return event
        }

        guard !isSettingsWindowActive() else { return event }

        if let handled = handleClipboardShortcuts(event) { return handled }
        if let handled = handleAppShortcuts(event) { return handled }
        if let handled = handleQuickSelect(event) { return handled }

        return event
    }

    private func isSettingsWindowActive() -> Bool {
        guard let keyWindow = NSApp.keyWindow else { return false }
        return keyWindow.title == "Settings"
            || keyWindow.contentView?.subviews.contains {
                String(describing: type(of: $0)).contains("SettingsView")
            } ?? false
    }

    private func handleClipboardShortcuts(_ event: NSEvent) -> NSEvent? {
        guard isClipboardMode else { return nil }
        guard matchesShortcut(event, settings.saveClipboardShortcut) else { return nil }
        guard selectedIndex < clipboardHistory.count else { return nil }

        let entry = clipboardHistory[selectedIndex]
        switch entry.type {
        case .text: handleSaveAsSnippet()
        case .image: handleSaveImage()
        case .unknown: break
        }
        return nil
    }

    private func handleAppShortcuts(_ event: NSEvent) -> NSEvent? {
        guard !isClipboardMode else { return nil }

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
        return nil
    }

    private func handleQuickSelect(_ event: NSEvent) -> NSEvent? {
        guard let char = event.charactersIgnoringModifiers?.first,
            let digit = char.wholeNumberValue,
            digit >= 1, digit <= 9
        else { return nil }

        let shouldTrigger: Bool =
            switch settings.quickSelectModifier {
            case .option: event.modifierFlags.contains(.option)
            case .command: event.modifierFlags.contains(.command)
            case .control: event.modifierFlags.contains(.control)
            }

        guard shouldTrigger else { return nil }
        handleAltNumber(digit)
        return nil
    }
}

extension SearchEngine: ObservableObject {}
