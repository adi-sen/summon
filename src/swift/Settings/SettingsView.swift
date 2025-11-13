import SwiftUI

struct SettingsView: View {
	@ObservedObject var settings = AppSettings.shared
	@ObservedObject var dropdownState = DropdownStateManager.shared
	@State private var selectedTab = 0
	@State private var eventMonitor: Any?

	var body: some View {
		ZStack {
			mainContent
		}
		.frame(
			minWidth: 1200,
			idealWidth: 1400,
			maxWidth: .infinity,
			minHeight: 800,
			idealHeight: 900,
			maxHeight: .infinity
		)
		.onAppear { setupEventMonitor() }
		.onDisappear { removeEventMonitor() }
	}

	private var mainContent: some View {
		VStack(spacing: 0) {
			tabBar
			Divider().background(Color.white.opacity(0.1))
			selectedTabView
		}
		.background(backgroundColor)
		.onChange(of: settings.theme) { _ in settings.scheduleSave() }
		.onChange(of: settings.customFontName) { _ in settings.scheduleSave() }
		.onChange(of: settings.fontSize) { _ in settings.scheduleSave() }
		.onChange(of: settings.showTrayIcon) { newValue in
			settings.scheduleSave()
			NotificationCenter.default.post(name: .trayIconSettingChanged, object: newValue)
		}
		.onChange(of: settings.showDockIcon) { newValue in
			settings.scheduleSave()
			NotificationCenter.default.post(name: .dockIconSettingChanged, object: newValue)
		}
		.onChange(of: settings.hideTrafficLights) { newValue in
			settings.scheduleSave()
			NotificationCenter.default.post(name: .trafficLightsSettingChanged, object: newValue)
		}
		.onChange(of: settings.maxResults) { _ in settings.scheduleSave() }
		.onChange(of: settings.maxClipboardItems) { _ in settings.scheduleSave() }
		.onChange(of: settings.clipboardRetentionDays) { _ in settings.scheduleSave() }
	}

	private var backgroundColor: Color {
		settings.backgroundColorUI
	}

	private var tabBar: some View {
		HStack(spacing: 0) {
			TabButton(title: "General", isSelected: selectedTab == 0) {
				selectedTab = 0
				NotificationCenter.default.post(name: .closeAllDropdowns, object: nil)
			}
			TabButton(title: "Appearance", isSelected: selectedTab == 1) {
				selectedTab = 1
				NotificationCenter.default.post(name: .closeAllDropdowns, object: nil)
			}
			TabButton(title: "Search", isSelected: selectedTab == 2) {
				selectedTab = 2
				NotificationCenter.default.post(name: .closeAllDropdowns, object: nil)
			}
			TabButton(title: "Clipboard", isSelected: selectedTab == 3) {
				selectedTab = 3
				NotificationCenter.default.post(name: .closeAllDropdowns, object: nil)
			}
			TabButton(title: "Commands", isSelected: selectedTab == 4) {
				selectedTab = 4
				NotificationCenter.default.post(name: .closeAllDropdowns, object: nil)
			}
			TabButton(title: "Snippets", isSelected: selectedTab == 5) {
				selectedTab = 5
				NotificationCenter.default.post(name: .closeAllDropdowns, object: nil)
			}
			TabButton(title: "Web Searches", isSelected: selectedTab == 6) {
				selectedTab = 6
				NotificationCenter.default.post(name: .closeAllDropdowns, object: nil)
			}
			TabButton(title: "Extensions", isSelected: selectedTab == 7) {
				selectedTab = 7
				NotificationCenter.default.post(name: .closeAllDropdowns, object: nil)
			}
			TabButton(title: "Shortcuts", isSelected: selectedTab == 8) {
				selectedTab = 8
				NotificationCenter.default.post(name: .closeAllDropdowns, object: nil)
			}
			Spacer()
		}
		.padding(.horizontal, DesignTokens.Spacing.xxl)
		.padding(.vertical, DesignTokens.Spacing.md)
		.background(backgroundColor)
	}

	@ViewBuilder
	private var selectedTabView: some View {
		switch selectedTab {
		case 0: GeneralSettingsTab()
		case 1: AppearanceSettingsTab()
		case 2: SearchSettingsTab()
		case 3: ClipboardSettingsTab()
		case 4: CommandsSettingsTab()
		case 5: SnippetsSettingsTab()
		case 6: WebSearchesSettingsTab()
		case 7: ExtensionsSettingsTab()
		case 8: ShortcutsSettingsTab()
		default: ShortcutsSettingsTab()
		}
	}

	private func setupEventMonitor() {
		eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
			if dropdownState.isAnyDropdownOpen {
				return event
			}

			if event.modifierFlags.contains(.command) {
				switch event.charactersIgnoringModifiers {
				case "1":
					selectedTab = 0
					return nil
				case "2":
					selectedTab = 1
					return nil
				case "3":
					selectedTab = 2
					return nil
				case "4":
					selectedTab = 3
					return nil
				case "5":
					selectedTab = 4
					return nil
				case "6":
					selectedTab = 5
					return nil
				case "7":
					selectedTab = 6
					return nil
				case "8":
					selectedTab = 7
					return nil
				case "9":
					selectedTab = 8
					return nil
				case "q":
					NSApp.keyWindow?.close()
					return nil
				default: break
				}

				let quickSelectModifier = settings.quickSelectModifier
				if quickSelectModifier == .command,
				   let chars = event.charactersIgnoringModifiers,
				   chars.allSatisfy(\.isNumber)
				{
					return nil
				}
			}

			let quickSelectModifier = settings.quickSelectModifier
			if quickSelectModifier != .command {
				let hasModifier =
					(quickSelectModifier == .option && event.modifierFlags.contains(.option))
					|| (quickSelectModifier == .control && event.modifierFlags.contains(.control))

				if let chars = event.charactersIgnoringModifiers, hasModifier,
				   chars.allSatisfy(\.isNumber)
				{
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

struct TabButton: View {
	let title: String
	let isSelected: Bool
	let action: () -> Void
	@ObservedObject var settings = AppSettings.shared

	var body: some View {
		Button(action: action) {
			Text(title)
				.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
				.foregroundColor(isSelected ? settings.accentColorUI : settings.secondaryTextColorUI)
				.padding(.horizontal, DesignTokens.Spacing.lg)
				.padding(.vertical, DesignTokens.Spacing.sm)
				.background(isSelected ? settings.accentColorUI.opacity(0.15) : Color.clear)
				.cornerRadius(DesignTokens.CornerRadius.md)
		}
		.buttonStyle(PlainButtonStyle())
	}
}

struct GeneralSettingsTab: View {
	@ObservedObject var settings = AppSettings.shared

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 24) {
				SettingSection(title: "INTERFACE") {
					VStack(alignment: .leading, spacing: 16) {
						SettingRow(label: "Show Tray Icon") {
							Switch(isOn: $settings.showTrayIcon)
						}

						SettingRow(label: "Show Dock Icon") {
							Switch(isOn: $settings.showDockIcon)
						}

						SettingRow(label: "Hide Traffic Lights") {
							Switch(isOn: $settings.hideTrafficLights)
						}
					}
				}
			}
			.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
		}
		.background(settings.backgroundColorUI)
	}
}

struct AppearanceSettingsTab: View {
	@ObservedObject var settings = AppSettings.shared
	@State private var themeMenuExpanded = false

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 24) {
				SettingSection(title: "THEME") {
					Dropdown(
						items: Theme.allCases,
						selection: $settings.theme,
						label: { $0.name },
						isExpanded: $themeMenuExpanded,
						width: 180
					)
				}

				SettingSection(title: "FONT") {
					FontPickerMenu(selectedFont: $settings.customFontName)
				}
			}
			.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
		}
		.background(settings.backgroundColorUI)
	}
}

struct SearchSettingsTab: View {
	@ObservedObject var settings = AppSettings.shared
	@State private var showingFolderPicker = false

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 24) {
				SettingSection(title: "RESULTS") {
					VStack(alignment: .leading, spacing: 12) {
						SettingRow(label: "Max Results") {
							RangeSlider(
								value: Binding(
									get: { Double(settings.maxResults) },
									set: { settings.maxResults = Int($0) }
								),
								range: 5 ... 20,
								step: 1,
								valueLabel: { "\(Int($0))" }
							)
						}
					}
				}

				SettingSection(title: "SEARCH FOLDERS") {
					VStack(alignment: .leading, spacing: 12) {
						Text(
							"At least one folder must be configured. Add or remove folders to customize your search."
						)
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(settings.secondaryTextColorUI)
						.padding(.bottom, 8)

						ForEach(settings.searchFolders, id: \.self) { folder in
							HStack {
								Image(systemName: "folder.fill")
									.foregroundColor(.blue)
								Text(folder)
									.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
									.foregroundColor(settings.textColorUI)
									.lineLimit(1)
								Spacer()
								Button(action: {
									if settings.searchFolders.count > 1 {
										settings.searchFolders.removeAll { $0 == folder }
										settings.saveAndReindex()
									}
								}) {
									Image(systemName: "xmark.circle.fill")
										.foregroundColor(settings.secondaryTextColorUI
											.opacity(settings.searchFolders.count > 1 ? 1.0 : 0.3))
								}
								.buttonStyle(PlainButtonStyle())
								.disabled(settings.searchFolders.count == 1)
							}
							.padding(.vertical, DesignTokens.Spacing.sm)
							.padding(.horizontal, DesignTokens.Spacing.lg)
							.background(settings.searchBarColorUI)
							.cornerRadius(DesignTokens.CornerRadius.md)
						}

						Button(action: {
							showingFolderPicker = true
						}) {
							HStack {
								Image(systemName: "plus.circle.fill")
								Text("Add Folder")
							}
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
							.foregroundColor(settings.accentColorUI)
						}
						.buttonStyle(PlainButtonStyle())
					}
				}
			}
			.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
		}
		.background(settings.backgroundColorUI)
		.overlay {
			if showingFolderPicker {
				Color.black.opacity(0.4)
					.ignoresSafeArea()
					.onTapGesture {
						showingFolderPicker = false
					}

				FolderPicker(
					isPresented: $showingFolderPicker,
					onSelect: { path in
						if !settings.searchFolders.contains(path) {
							settings.searchFolders.append(path)
							settings.saveAndReindex()
						}
					}
				)
			}
		}
	}
}

struct ClipboardSettingsTab: View {
	@ObservedObject var settings = AppSettings.shared

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 24) {
				SettingSection(title: "CLIPBOARD HISTORY") {
					VStack(alignment: .leading, spacing: 12) {
						SettingRow(label: "Max Items") {
							RangeSlider(
								value: Binding(
									get: { Double(settings.maxClipboardItems) },
									set: { settings.maxClipboardItems = Int($0) }
								),
								range: 5 ... 50,
								step: 5,
								valueLabel: { "\(Int($0))" }
							)
						}

						SettingRow(label: "Keep For") {
							RangeSlider(
								value: Binding(
									get: { Double(settings.clipboardRetentionDays) },
									set: { settings.clipboardRetentionDays = Int($0) }
								),
								range: 1 ... 30,
								step: 1,
								valueLabel: { "\(Int($0)) day\(Int($0) == 1 ? "" : "s")" }
							)
						}
					}
				}
			}
			.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
		}
		.background(settings.backgroundColorUI)
	}
}

struct CommandsSettingsTab: View {
	@ObservedObject var settings = AppSettings.shared

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 24) {
				SettingSection(title: "COMMAND SHORTCUTS") {
					VStack(alignment: .leading, spacing: 16) {
						HStack {
							VStack(alignment: .leading, spacing: 4) {
								Text("Enable Commands")
									.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
									.foregroundColor(settings.textColorUI)

								Text("Enable commands like 'settings', 'quit', 'clipboard'")
									.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
									.foregroundColor(settings.secondaryTextColorUI.opacity(0.7))
							}

							Spacer()

							Switch(
								isOn: Binding(
									get: { settings.enableCommands },
									set: { newValue in
										settings.enableCommands = newValue
										settings.scheduleSave()
									}
								))
						}
					}
				}
			}
			.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
		}
		.background(settings.backgroundColorUI)
	}
}

struct SnippetsSettingsTab: View {
	@ObservedObject var settings = AppSettings.shared
	@ObservedObject var snippetManager = SnippetManager.shared
	@State private var showingAddSnippet = false
	@State private var eventMonitor: Any?

	var body: some View {
		Group {
			if snippetManager.snippets.isEmpty {
				VStack {
					Spacer()
					VStack(spacing: DesignTokens.Spacing.md) {
						Image(systemName: "text.quote")
							.font(.system(size: 48))
							.foregroundColor(settings.secondaryTextColorUI.opacity(0.4))
						Text("No snippets yet")
							.font(Font(settings.uiFont.withSize(15)))
							.foregroundColor(settings.secondaryTextColorUI)

						Button(action: { showingAddSnippet = true }) {
							HStack(spacing: DesignTokens.Spacing.md) {
								Image(systemName: "plus.circle.fill")
									.font(.system(size: DesignTokens.Typography.body))
								Text("Add Snippet")
									.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
							}
							.foregroundColor(
								Color(
									red: settings.theme.accentColor.0,
									green: settings.theme.accentColor.1,
									blue: settings.theme.accentColor.2
								)
							)
							.padding(.horizontal, DesignTokens.Spacing.xl)
							.padding(.vertical, DesignTokens.Spacing.md)
							.background(settings.searchBarColorUI)
							.cornerRadius(DesignTokens.CornerRadius.md)
							.overlay(
								RoundedRectangle(cornerRadius: 6)
									.stroke(
										Color(
											red: settings.theme.accentColor.0,
											green: settings.theme.accentColor.1,
											blue: settings.theme.accentColor.2
										).opacity(0.3), lineWidth: 1
									)
							)
						}
						.buttonStyle(PlainButtonStyle())
						.padding(.top, 8)

						Text("Or press ⌘N")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
							.foregroundColor(
								Color(
									red: settings.theme.secondaryTextColor.0,
									green: settings.theme.secondaryTextColor.1,
									blue: settings.theme.secondaryTextColor.2
								).opacity(0.5)
							)
							.padding(.top, 4)
					}
					Spacer()
				}
				.background(
					Color(
						red: settings.theme.backgroundColor.0,
						green: settings.theme.backgroundColor.1,
						blue: settings.theme.backgroundColor.2
					))
			} else {
				SnippetsList()
					.background(
						Color(
							red: settings.theme.backgroundColor.0,
							green: settings.theme.backgroundColor.1,
							blue: settings.theme.backgroundColor.2
						))
			}
		}
		.sheet(isPresented: $showingAddSnippet) {
			AddSnippetView()
		}
		.onAppear {
			setupEventMonitor()
		}
		.onDisappear {
			if let monitor = eventMonitor {
				NSEvent.removeMonitor(monitor)
				eventMonitor = nil
			}
		}
	}

	private func setupEventMonitor() {
		if let monitor = eventMonitor {
			NSEvent.removeMonitor(monitor)
		}

		eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
			if event.modifierFlags.contains(.command),
			   event.charactersIgnoringModifiers == "n"
			{
				showingAddSnippet = true
				return nil
			}
			return event
		}
	}
}

struct SnippetsTableView: NSViewRepresentable {
	@ObservedObject var settings = AppSettings.shared
	@ObservedObject var snippetManager = SnippetManager.shared

	class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {
		var parent: SnippetsTableView
		weak var tableView: NSTableView?

		init(_ parent: SnippetsTableView) {
			self.parent = parent
		}

		func numberOfRows(in _: NSTableView) -> Int {
			parent.snippetManager.snippets.count
		}

		func tableView(_: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
			guard row < parent.snippetManager.snippets.count else { return nil }
			let snippet = parent.snippetManager.snippets[row]

			let columnId = tableColumn?.identifier.rawValue ?? ""
			let identifier = NSUserInterfaceItemIdentifier(columnId)

			switch columnId {
			case "enabled":
				let cellView = NSTableCellView()
				cellView.identifier = identifier

				let toggle = NSSwitch()
				toggle.state = snippet.enabled ? .on : .off
				toggle.target = self
				toggle.action = #selector(toggleSnippet(_:))
				toggle.tag = row

				cellView.addSubview(toggle)
				toggle.translatesAutoresizingMaskIntoConstraints = false
				NSLayoutConstraint.activate([
					toggle.centerXAnchor.constraint(equalTo: cellView.centerXAnchor),
					toggle.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
				])
				return cellView

			case "trigger":
				let cellView = NSTableCellView()
				cellView.identifier = identifier
				cellView.wantsLayer = true
				cellView.layer?.backgroundColor =
					NSColor(
						Color(
							red: parent.settings.theme.searchBarColor.0,
							green: parent.settings.theme.searchBarColor.1,
							blue: parent.settings.theme.searchBarColor.2
						)
					).cgColor
				cellView.layer?.cornerRadius = 6

				let textField = NSTextField()
				textField.stringValue = snippet.trigger
				textField.isEditable = true
				textField.isBordered = false
				textField.focusRingType = .none
				textField.backgroundColor = .clear
				textField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
				textField.textColor = NSColor(
					Color(
						red: parent.settings.theme.accentColor.0,
						green: parent.settings.theme.accentColor.1,
						blue: parent.settings.theme.accentColor.2
					))
				textField.delegate = self
				textField.tag = row
				cellView.addSubview(textField)
				textField.translatesAutoresizingMaskIntoConstraints = false
				NSLayoutConstraint.activate([
					textField.leadingAnchor.constraint(
						equalTo: cellView.leadingAnchor, constant: 16
					),
					textField.trailingAnchor.constraint(
						equalTo: cellView.trailingAnchor, constant: -16
					),
					textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
				])
				return cellView

			case "content":
				let cellView = NSTableCellView()
				cellView.identifier = identifier
				cellView.wantsLayer = true
				cellView.layer?.backgroundColor =
					NSColor(
						Color(
							red: parent.settings.theme.searchBarColor.0,
							green: parent.settings.theme.searchBarColor.1,
							blue: parent.settings.theme.searchBarColor.2
						)
					).cgColor
				cellView.layer?.cornerRadius = 6

				let textField = NSTextField()
				textField.stringValue = snippet.content
				textField.isEditable = true
				textField.isBordered = false
				textField.focusRingType = .none
				textField.backgroundColor = .clear
				textField.font = NSFont.systemFont(ofSize: 13)
				textField.textColor = NSColor(
					Color(
						red: parent.settings.theme.textColor.0,
						green: parent.settings.theme.textColor.1,
						blue: parent.settings.theme.textColor.2
					))
				textField.delegate = self
				textField.tag = row
				textField.lineBreakMode = .byTruncatingTail
				cellView.addSubview(textField)
				textField.translatesAutoresizingMaskIntoConstraints = false
				NSLayoutConstraint.activate([
					textField.leadingAnchor.constraint(
						equalTo: cellView.leadingAnchor, constant: 16
					),
					textField.trailingAnchor.constraint(
						equalTo: cellView.trailingAnchor, constant: -16
					),
					textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
				])
				return cellView

			case "actions":
				let cellView = NSTableCellView()
				cellView.identifier = identifier
				let stackView = NSStackView()
				stackView.orientation = .horizontal
				stackView.spacing = 6

				let duplicateButton = NSButton()
				duplicateButton.image = NSImage(
					systemSymbolName: "doc.on.doc", accessibilityDescription: "Duplicate"
				)
				duplicateButton.bezelStyle = .regularSquare
				duplicateButton.isBordered = false
				duplicateButton.target = self
				duplicateButton.action = #selector(duplicateSnippet(_:))
				duplicateButton.tag = row

				let deleteButton = NSButton()
				deleteButton.image = NSImage(
					systemSymbolName: "trash", accessibilityDescription: "Delete"
				)
				deleteButton.bezelStyle = .regularSquare
				deleteButton.isBordered = false
				deleteButton.target = self
				deleteButton.action = #selector(deleteSnippet(_:))
				deleteButton.tag = row

				stackView.addArrangedSubview(duplicateButton)
				stackView.addArrangedSubview(deleteButton)

				cellView.addSubview(stackView)
				stackView.translatesAutoresizingMaskIntoConstraints = false
				NSLayoutConstraint.activate([
					stackView.centerXAnchor.constraint(equalTo: cellView.centerXAnchor),
					stackView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
				])
				return cellView

			default:
				return nil
			}
		}

		func controlTextDidEndEditing(_ obj: Notification) {
			print("[SnippetsTable] controlTextDidEndEditing called")

			guard let textField = obj.object as? NSTextField else {
				print("[SnippetsTable] ERROR: notification object is not NSTextField")
				return
			}

			let row = textField.tag
			print("[SnippetsTable] Row: \(row), Text: '\(textField.stringValue)'")

			guard row >= 0, row < parent.snippetManager.snippets.count else {
				print(
					"[SnippetsTable] ERROR: Invalid row \(row), count: \(parent.snippetManager.snippets.count)"
				)
				return
			}

			var snippet = parent.snippetManager.snippets[row]
			print("[SnippetsTable] Current snippet: '\(snippet.trigger)' -> '\(snippet.content)'")

			guard let cellView = textField.superview else {
				print("[SnippetsTable] ERROR: textField.superview is nil")
				return
			}

			var currentView: NSView? = cellView
			var tableView: NSTableView?
			while let view = currentView {
				if let table = view as? NSTableView {
					tableView = table
					break
				}
				currentView = view.superview
			}

			guard let tableView else {
				print("[SnippetsTable] ERROR: Could not find NSTableView in hierarchy")
				return
			}

			let columnIndex = tableView.column(for: cellView)
			guard columnIndex >= 0, columnIndex < tableView.tableColumns.count else {
				print("[SnippetsTable] ERROR: Invalid column index \(columnIndex)")
				return
			}

			let column = tableView.tableColumns[columnIndex]
			print("[SnippetsTable] Column: \(column.identifier.rawValue)")

			if column.identifier.rawValue == "trigger" {
				snippet.trigger = textField.stringValue
				print("[SnippetsTable] Updated trigger to: '\(snippet.trigger)'")
			} else if column.identifier.rawValue == "content" {
				snippet.content = textField.stringValue
				print("[SnippetsTable] Updated content to: '\(snippet.content)'")
			}

			parent.snippetManager.update(snippet)
			tableView.reloadData()
		}

		@objc func toggleSnippet(_ sender: NSSwitch) {
			let row = sender.tag
			guard row < parent.snippetManager.snippets.count else { return }
			var snippet = parent.snippetManager.snippets[row]
			snippet.enabled = sender.state == .on
			parent.snippetManager.update(snippet)
		}

		@objc func duplicateSnippet(_ sender: NSButton) {
			let row = sender.tag
			guard row < parent.snippetManager.snippets.count else { return }
			var snippet = parent.snippetManager.snippets[row]
			snippet.id = UUID().uuidString
			snippet.trigger += "_copy"
			parent.snippetManager.add(snippet)
		}

		@objc func deleteSnippet(_ sender: NSButton) {
			let row = sender.tag
			guard row < parent.snippetManager.snippets.count else { return }
			let snippet = parent.snippetManager.snippets[row]
			parent.snippetManager.delete(snippet)
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	func makeNSView(context: Context) -> NSScrollView {
		let scrollView = NSScrollView()
		let tableView = ThemedTableView()

		tableView.settings = settings

		let enabledColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
		enabledColumn.title = "Enabled"
		enabledColumn.width = 70
		enabledColumn.minWidth = 70
		enabledColumn.maxWidth = 70

		let triggerColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("trigger"))
		triggerColumn.title = "Trigger"
		triggerColumn.width = 180
		triggerColumn.minWidth = 120

		let contentColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
		contentColumn.title = "Content"
		contentColumn.width = 420
		contentColumn.minWidth = 220

		let actionsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("actions"))
		actionsColumn.title = "Actions"
		actionsColumn.width = 90
		actionsColumn.minWidth = 90
		actionsColumn.maxWidth = 90

		tableView.addTableColumn(enabledColumn)
		tableView.addTableColumn(triggerColumn)
		tableView.addTableColumn(contentColumn)
		tableView.addTableColumn(actionsColumn)

		tableView.delegate = context.coordinator
		tableView.dataSource = context.coordinator
		tableView.rowHeight = 44
		tableView.intercellSpacing = NSSize(width: 12, height: 10)
		tableView.headerView = ThemedTableHeaderView(settings: settings)
		tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
		tableView.gridStyleMask = []
		tableView.selectionHighlightStyle = .none

		context.coordinator.tableView = tableView

		scrollView.documentView = tableView
		scrollView.hasVerticalScroller = true
		scrollView.hasHorizontalScroller = false
		scrollView.autohidesScrollers = true
		scrollView.drawsBackground = false
		scrollView.backgroundColor = NSColor(
			Color(
				red: settings.theme.backgroundColor.0,
				green: settings.theme.backgroundColor.1,
				blue: settings.theme.backgroundColor.2
			))

		return scrollView
	}

	func updateNSView(_ scrollView: NSScrollView, context _: Context) {
		if let tableView = scrollView.documentView as? ThemedTableView {
			tableView.settings = settings
			tableView.reloadData()
		}
	}
}

class ThemedTableView: NSTableView {
	var settings: AppSettings = .shared

	override func drawGrid(inClipRect clipRect: NSRect) {
		let gridColor = NSColor(
			Color(
				red: settings.theme.metadataColor.0,
				green: settings.theme.metadataColor.1,
				blue: settings.theme.metadataColor.2
			).opacity(0.3))
		gridColor.setStroke()
		super.drawGrid(inClipRect: clipRect)
	}

	override var backgroundColor: NSColor {
		get {
			NSColor(
				Color(
					red: settings.theme.backgroundColor.0,
					green: settings.theme.backgroundColor.1,
					blue: settings.theme.backgroundColor.2
				))
		}
		set {}
	}
}

class ThemedTableHeaderView: NSTableHeaderView {
	var settings: AppSettings

	init(settings: AppSettings) {
		self.settings = settings
		super.init(frame: .zero)
	}

	required init?(coder: NSCoder) {
		settings = AppSettings.shared
		super.init(coder: coder)
	}

	override func draw(_ dirtyRect: NSRect) {
		NSColor(
			Color(
				red: settings.theme.searchBarColor.0,
				green: settings.theme.searchBarColor.1,
				blue: settings.theme.searchBarColor.2
			)
		).setFill()
		dirtyRect.fill()
		super.draw(dirtyRect)
	}
}

struct ShortcutsSettingsTab: View {
	@ObservedObject var settings = AppSettings.shared
	@State private var quickSelectMenuExpanded = false

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 24) {
				SettingSection(title: "GLOBAL SHORTCUTS") {
					VStack(alignment: .leading, spacing: 12) {
						ShortcutRecorderView(
							label: "Show Launcher", shortcut: $settings.launcherShortcut
						)
						ShortcutRecorderView(
							label: "Clipboard History", shortcut: $settings.clipboardShortcut
						)
					}
				}

				SettingSection(title: "NAVIGATION") {
					VStack(alignment: .leading, spacing: 8) {
						ShortcutInfoRow(
							keys: "↑/↓ or ⌃J/⌃K or ⌃N/⌃P", description: "Navigate results"
						)
						ShortcutInfoRow(keys: "↩ (Enter)", description: "Select item")
						ShortcutInfoRow(keys: "Esc", description: "Hide window")
					}
				}

				SettingSection(title: "QUICK SELECT") {
					VStack(alignment: .leading, spacing: 12) {
						SettingRow(label: "Press modifier + 1-9 to quickly select results") {
							Dropdown(
								items: QuickSelectModifier.allCases,
								selection: Binding(
									get: { settings.quickSelectModifier },
									set: { newValue in
										settings.quickSelectModifier = newValue
										settings.scheduleSave()
									}
								),
								label: { $0.name },
								isExpanded: $quickSelectMenuExpanded,
								alignRight: true,
								width: 110
							)
							.frame(width: 110, alignment: .trailing)
						}
					}
				}
			}
			.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
		}
		.background(settings.backgroundColorUI)
		.onChange(of: settings.launcherShortcut) { _ in
			settings.scheduleSave()
			NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
		}
		.onChange(of: settings.clipboardShortcut) { _ in
			settings.scheduleSave()
			NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
		}
	}
}

struct ShortcutInfoRow: View {
	let keys: String
	let description: String
	@ObservedObject var settings = AppSettings.shared

	var body: some View {
		HStack {
			Text(keys)
				.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
				.foregroundColor(
					Color(
						red: settings.theme.accentColor.0,
						green: settings.theme.accentColor.1,
						blue: settings.theme.accentColor.2
					)
				)
				.padding(.horizontal, DesignTokens.Spacing.md)
				.padding(.vertical, DesignTokens.Spacing.xs)
				.background(
					Color(
						red: settings.theme.metadataColor.0,
						green: settings.theme.metadataColor.1,
						blue: settings.theme.metadataColor.2
					)
				)
				.cornerRadius(DesignTokens.CornerRadius.sm)

			Text(description)
				.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
				.foregroundColor(
					Color(
						red: settings.theme.secondaryTextColor.0,
						green: settings.theme.secondaryTextColor.1,
						blue: settings.theme.secondaryTextColor.2
					))
		}
		.padding(.vertical, DesignTokens.Spacing.xxs)
	}
}

struct SettingSection<Content: View>: View {
	let title: String
	let content: Content
	@ObservedObject var settings = AppSettings.shared

	init(title: String, @ViewBuilder content: () -> Content) {
		self.title = title
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text(title)
				.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
				.foregroundColor(
					Color(
						red: settings.theme.secondaryTextColor.0,
						green: settings.theme.secondaryTextColor.1,
						blue: settings.theme.secondaryTextColor.2
					).opacity(0.8))

			VStack(alignment: .leading, spacing: 10) {
				content
			}
		}
	}
}

struct SettingRow<Content: View>: View {
	let label: String
	let content: Content
	@ObservedObject var settings = AppSettings.shared

	init(label: String, @ViewBuilder content: () -> Content) {
		self.label = label
		self.content = content()
	}

	var body: some View {
		HStack {
			Text(label)
				.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
				.foregroundColor(
					Color(
						red: settings.theme.textColor.0,
						green: settings.theme.textColor.1,
						blue: settings.theme.textColor.2
					))

			Spacer()

			content
		}
		.padding(.vertical, DesignTokens.Spacing.xxs)
	}
}

struct AddSnippetView: View {
	@Environment(\.presentationMode) var presentationMode
	@ObservedObject var settings = AppSettings.shared
	@ObservedObject var snippetManager = SnippetManager.shared

	@State private var trigger = ""
	@State private var content = ""

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Add Snippet")
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.large)))
					.foregroundColor(
						Color(
							red: settings.theme.textColor.0,
							green: settings.theme.textColor.1,
							blue: settings.theme.textColor.2
						))
				Spacer()
				Button(action: { presentationMode.wrappedValue.dismiss() }) {
					Image(systemName: "xmark.circle.fill")
						.font(.system(size: DesignTokens.Typography.large + 2))
						.foregroundColor(
							Color(
								red: settings.theme.secondaryTextColor.0,
								green: settings.theme.secondaryTextColor.1,
								blue: settings.theme.secondaryTextColor.2
							))
				}
				.buttonStyle(PlainButtonStyle())
			}
			.padding(DesignTokens.Spacing.xl)
			.background(
				Color(
					red: settings.theme.backgroundColor.0,
					green: settings.theme.backgroundColor.1,
					blue: settings.theme.backgroundColor.2
				))

			Divider()
				.background(Color.white.opacity(0.1))

			VStack(alignment: .leading, spacing: 16) {
				VStack(alignment: .leading, spacing: 6) {
					Text("Trigger")
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(
							Color(
								red: settings.theme.textColor.0,
								green: settings.theme.textColor.1,
								blue: settings.theme.textColor.2
							))
					TextField("e.g., \\email", text: $trigger)
						.textFieldStyle(PlainTextFieldStyle())
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
						.foregroundColor(
							Color(
								red: settings.theme.textColor.0,
								green: settings.theme.textColor.1,
								blue: settings.theme.textColor.2
							)
						)
						.padding(DesignTokens.Spacing.md + 2)
						.background(settings.searchBarColorUI)
						.cornerRadius(DesignTokens.CornerRadius.md)
				}

				VStack(alignment: .leading, spacing: 6) {
					Text("Content")
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(
							Color(
								red: settings.theme.textColor.0,
								green: settings.theme.textColor.1,
								blue: settings.theme.textColor.2
							))
					ThemedTextEditor(
						text: $content,
						backgroundColor: Color(
							red: settings.theme.searchBarColor.0,
							green: settings.theme.searchBarColor.1,
							blue: settings.theme.searchBarColor.2
						),
						textColor: Color(
							red: settings.theme.textColor.0,
							green: settings.theme.textColor.1,
							blue: settings.theme.textColor.2
						)
					)
					.frame(height: 120)
					.cornerRadius(DesignTokens.CornerRadius.md)
				}

				HStack(spacing: DesignTokens.Spacing.md + 2) {
					Spacer()
					Button("Cancel") {
						presentationMode.wrappedValue.dismiss()
					}
					.buttonStyle(PlainButtonStyle())
					.foregroundColor(
						Color(
							red: settings.theme.textColor.0,
							green: settings.theme.textColor.1,
							blue: settings.theme.textColor.2
						)
					)
					.padding(.horizontal, DesignTokens.Spacing.xl)
					.padding(.vertical, DesignTokens.Spacing.md)
					.background(
						Color(
							red: settings.theme.metadataColor.0,
							green: settings.theme.metadataColor.1,
							blue: settings.theme.metadataColor.2
						)
					)
					.cornerRadius(DesignTokens.CornerRadius.md)

					Button("Add") {
						let snippet = Snippet(trigger: trigger, content: content)
						snippetManager.add(snippet)
						presentationMode.wrappedValue.dismiss()
					}
					.buttonStyle(PlainButtonStyle())
					.foregroundColor(Color.white)
					.padding(.horizontal, DesignTokens.Spacing.xl)
					.padding(.vertical, DesignTokens.Spacing.md)
					.background(
						Color(
							red: settings.theme.accentColor.0,
							green: settings.theme.accentColor.1,
							blue: settings.theme.accentColor.2
						)
					)
					.cornerRadius(DesignTokens.CornerRadius.md)
					.disabled(trigger.isEmpty || content.isEmpty)
					.opacity(trigger.isEmpty || content.isEmpty ? 0.5 : 1.0)
				}
				.padding(.top, 4)
			}
			.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
		}
		.frame(width: 480, height: 360)
		.background(
			Color(
				red: settings.theme.backgroundColor.0,
				green: settings.theme.backgroundColor.1,
				blue: settings.theme.backgroundColor.2
			))
	}
}

struct ThemedTextEditor: NSViewRepresentable {
	@Binding var text: String
	let backgroundColor: Color
	let textColor: Color

	func makeNSView(context: Context) -> NSScrollView {
		let scrollView = NSTextView.scrollableTextView()
		guard let textView = scrollView.documentView as? NSTextView else {
			return scrollView
		}

		textView.delegate = context.coordinator
		textView.isRichText = false
		textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
		textView.textContainerInset = NSSize(width: 8, height: 8)
		textView.autoresizingMask = [.width, .height]
		textView.backgroundColor = NSColor(backgroundColor)
		textView.textColor = NSColor(textColor)
		textView.insertionPointColor = NSColor(textColor)
		textView.drawsBackground = true

		return scrollView
	}

	func updateNSView(_ scrollView: NSScrollView, context _: Context) {
		guard let textView = scrollView.documentView as? NSTextView else { return }

		if textView.string != text {
			textView.string = text
		}

		textView.backgroundColor = NSColor(backgroundColor)
		textView.textColor = NSColor(textColor)
		textView.insertionPointColor = NSColor(textColor)
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	class Coordinator: NSObject, NSTextViewDelegate {
		var parent: ThemedTextEditor

		init(_ parent: ThemedTextEditor) {
			self.parent = parent
		}

		func textDidChange(_ notification: Notification) {
			guard let textView = notification.object as? NSTextView else { return }
			parent.text = textView.string
		}
	}
}

struct EditSnippetView: View {
	let snippet: Snippet
	@Environment(\.presentationMode) var presentationMode
	@ObservedObject var settings = AppSettings.shared
	@ObservedObject var snippetManager = SnippetManager.shared

	@State private var trigger: String
	@State private var content: String

	init(snippet: Snippet) {
		self.snippet = snippet
		_trigger = State(initialValue: snippet.trigger)
		_content = State(initialValue: snippet.content)
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Edit Snippet")
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.large)))
					.foregroundColor(
						Color(
							red: settings.theme.textColor.0,
							green: settings.theme.textColor.1,
							blue: settings.theme.textColor.2
						))
				Spacer()
				Button(action: { presentationMode.wrappedValue.dismiss() }) {
					Image(systemName: "xmark.circle.fill")
						.font(.system(size: DesignTokens.Typography.large + 2))
						.foregroundColor(
							Color(
								red: settings.theme.secondaryTextColor.0,
								green: settings.theme.secondaryTextColor.1,
								blue: settings.theme.secondaryTextColor.2
							))
				}
				.buttonStyle(PlainButtonStyle())
			}
			.padding(DesignTokens.Spacing.xl)
			.background(
				Color(
					red: settings.theme.backgroundColor.0,
					green: settings.theme.backgroundColor.1,
					blue: settings.theme.backgroundColor.2
				))

			Divider()
				.background(Color.white.opacity(0.1))

			VStack(alignment: .leading, spacing: 16) {
				VStack(alignment: .leading, spacing: 6) {
					Text("Trigger")
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(
							Color(
								red: settings.theme.textColor.0,
								green: settings.theme.textColor.1,
								blue: settings.theme.textColor.2
							))
					TextField("e.g., \\email", text: $trigger)
						.textFieldStyle(PlainTextFieldStyle())
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
						.foregroundColor(
							Color(
								red: settings.theme.textColor.0,
								green: settings.theme.textColor.1,
								blue: settings.theme.textColor.2
							)
						)
						.padding(DesignTokens.Spacing.md + 2)
						.background(settings.searchBarColorUI)
						.cornerRadius(DesignTokens.CornerRadius.md)
				}

				VStack(alignment: .leading, spacing: 6) {
					Text("Content")
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(
							Color(
								red: settings.theme.textColor.0,
								green: settings.theme.textColor.1,
								blue: settings.theme.textColor.2
							))
					ThemedTextEditor(
						text: $content,
						backgroundColor: Color(
							red: settings.theme.searchBarColor.0,
							green: settings.theme.searchBarColor.1,
							blue: settings.theme.searchBarColor.2
						),
						textColor: Color(
							red: settings.theme.textColor.0,
							green: settings.theme.textColor.1,
							blue: settings.theme.textColor.2
						)
					)
					.frame(height: 120)
					.cornerRadius(DesignTokens.CornerRadius.md)
				}

				HStack(spacing: DesignTokens.Spacing.md + 2) {
					Spacer()
					Button("Cancel") {
						presentationMode.wrappedValue.dismiss()
					}
					.buttonStyle(PlainButtonStyle())
					.foregroundColor(
						Color(
							red: settings.theme.textColor.0,
							green: settings.theme.textColor.1,
							blue: settings.theme.textColor.2
						)
					)
					.padding(.horizontal, DesignTokens.Spacing.xl)
					.padding(.vertical, DesignTokens.Spacing.md)
					.background(
						Color(
							red: settings.theme.metadataColor.0,
							green: settings.theme.metadataColor.1,
							blue: settings.theme.metadataColor.2
						)
					)
					.cornerRadius(DesignTokens.CornerRadius.md)

					Button("Save") {
						var updated = snippet
						updated.trigger = trigger
						updated.content = content
						snippetManager.update(updated)
						presentationMode.wrappedValue.dismiss()
					}
					.buttonStyle(PlainButtonStyle())
					.foregroundColor(Color.white)
					.padding(.horizontal, DesignTokens.Spacing.xl)
					.padding(.vertical, DesignTokens.Spacing.md)
					.background(
						Color(
							red: settings.theme.accentColor.0,
							green: settings.theme.accentColor.1,
							blue: settings.theme.accentColor.2
						)
					)
					.cornerRadius(DesignTokens.CornerRadius.md)
					.disabled(trigger.isEmpty || content.isEmpty)
					.opacity(trigger.isEmpty || content.isEmpty ? 0.5 : 1.0)
				}
				.padding(.top, 4)
			}
			.padding(DesignTokens.Spacing.xxl)
		}
		.frame(width: 440, height: 320)
		.background(
			Color(
				red: settings.theme.backgroundColor.0,
				green: settings.theme.backgroundColor.1,
				blue: settings.theme.backgroundColor.2
			))
	}
}

struct WebSearchesSettingsTab: View {
	@ObservedObject var settings = AppSettings.shared
	@ObservedObject var actionManager = ActionManager.shared

	var quickLinks: [Action] {
		actionManager.actions.filter { action in
			if case .quickLink = action.kind {
				return true
			}
			return false
		}
	}

	var body: some View {
		Group {
			if quickLinks.isEmpty {
				VStack {
					Spacer()
					VStack(spacing: DesignTokens.Spacing.xl) {
						Image(systemName: "magnifyingglass")
							.font(.system(size: 48))
							.foregroundColor(settings.secondaryTextColorUI.opacity(0.4))
						Text("No web searches yet")
							.font(Font(settings.uiFont.withSize(15)))
							.foregroundColor(settings.secondaryTextColorUI)

						HStack(spacing: DesignTokens.Spacing.lg) {
							Button(action: { actionManager.importDefaults() }) {
								HStack(spacing: DesignTokens.Spacing.sm) {
									Image(systemName: "arrow.counterclockwise")
										.font(.system(size: DesignTokens.Typography.small))
									Text("Import Defaults")
										.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
								}
								.foregroundColor(Color.white)
								.padding(.horizontal, DesignTokens.Spacing.xl)
								.padding(.vertical, DesignTokens.Spacing.md + 2)
								.background(settings.accentColorUI)
								.cornerRadius(DesignTokens.CornerRadius.md)
							}
							.buttonStyle(PlainButtonStyle())
						}
						.padding(.top, 8)

						Text("Or press ⌘N to add a web search")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
							.foregroundColor(settings.secondaryTextColorUI.opacity(0.5))
					}
					Spacer()
				}
				.background(settings.backgroundColorUI)
			} else {
				WebSearchesList()
					.background(settings.backgroundColorUI)
			}
		}
	}
}
