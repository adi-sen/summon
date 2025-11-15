import SwiftUI

struct SearchTab: View {
	@ObservedObject var settings: AppSettings
	@State private var showingFolderPicker = false
	@State private var folderPickerMode: FolderPickerMode = .appSearch
	@State private var selectedSection: SearchSection = .results
	@State private var showingAddEngine = false

	enum FolderPickerMode {
		case appSearch
		case fileSearch
	}

	enum SearchSection: String, CaseIterable {
		case results = "Results"
		case sources = "Sources"
		case webSearch = "Web Search"
	}

	var body: some View {
		HStack(spacing: 0) {
			VStack(alignment: .leading, spacing: 4) {
				ForEach(SearchSection.allCases, id: \.self) { section in
					SwiftUI.Button(action: {
						selectedSection = section
					}) {
						HStack(spacing: 8) {
							Image(systemName: iconForSection(section))
								.font(Font(settings.uiFont.withSize(13)))
								.foregroundColor(
									selectedSection == section
										? settings.accentColorUI : settings.secondaryTextColorUI
								)
								.frame(width: 16)
							Text(section.rawValue)
								.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
								.foregroundColor(
									selectedSection == section
										? settings.textColorUI : settings.secondaryTextColorUI)
							Spacer()
						}
						.padding(.horizontal, DesignTokens.Spacing.md)
						.padding(.vertical, DesignTokens.Spacing.sm)
						.background(
							selectedSection == section
								? settings.searchBarColorUI.opacity(0.5) : Color.clear
						)
						.cornerRadius(DesignTokens.CornerRadius.sm)
					}
					.buttonStyle(PlainButtonStyle())
				}
				Spacer()
			}
			.frame(width: 160)
			.padding(DesignTokens.Spacing.md)
			.background(settings.backgroundColorUI)

			Rectangle()
				.fill(settings.secondaryTextColorUI.opacity(0.1))
				.frame(width: 1)

			ScrollView(showsIndicators: false) {
				VStack(alignment: .leading, spacing: 20) {
					sectionContent
				}
				.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
			}
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
					onSelect: { folder in
						if folderPickerMode == .appSearch {
							if !settings.searchFolders.contains(folder) {
								settings.searchFolders.append(folder)
								settings.saveAndReindex()
							}
						} else {
							if !settings.fileSearchDirectories.contains(folder) {
								settings.fileSearchDirectories.append(folder)
								settings.scheduleSave()
								NotificationCenter.default.post(name: .refreshAppIndex, object: nil)
							}
						}
					}
				)
			}
		}
		.sheet(isPresented: $showingAddEngine) {
			AddSearchEngineView(onAdd: { name, url, icon, keyword in
				settings.addFallbackEngine(name: name, urlTemplate: url, iconName: icon)
				let id = settings.customFallbackEngines.last?.id ?? ""
				if !keyword.isEmpty, !id.isEmpty {
					settings.updateEngineKeyword(id: id, keyword: keyword)
				}
				showingAddEngine = false
			})
		}
	}

	private func iconForSection(_ section: SearchSection) -> String {
		switch section {
		case .results: "list.number"
		case .sources: "folder.fill"
		case .webSearch: "network"
		}
	}

	@ViewBuilder
	private var sectionContent: some View {
		switch selectedSection {
		case .results:
			resultsSection
		case .sources:
			sourcesSection
		case .webSearch:
			webSearchSection
		}
	}

	private var resultsSection: some View {
		VStack(alignment: .leading, spacing: 16) {
			ListItem(
				icon: .sfSymbol("list.number", settings.accentColorUI),
				title: "Maximum Results",
				subtitle: "Capped at 9 for optimal quick select (⌘1-9)"
			) {
				RangeSlider(
					value: Binding(
						get: { Double(settings.maxResults) },
						set: { settings.maxResults = Int($0) }
					),
					range: 5 ... 9,
					step: 1,
					valueLabel: { "\(Int($0))" }
				)
			}

			ListItem(
				icon: .sfSymbol("keyboard", settings.accentColorUI),
				title: "Quick Select Numbers",
				subtitle: "Show ⌘1-9 shortcuts next to results"
			) {
				Switch(
					isOn: Binding(
						get: { settings.showQuickSelect },
						set: {
							settings.showQuickSelect = $0
							settings.scheduleSave()
						}
					)
				)
			}
		}
	}

	private var sourcesSection: some View {
		VStack(alignment: .leading, spacing: 20) {
			VStack(alignment: .leading, spacing: 8) {
				sectionHeader(
					"Application Directories",
					subtitle: "Folders to scan for launchable applications"
				)

				ForEach(settings.searchFolders, id: \.self) { folder in
					folderRow(
						folder: folder,
						onDelete: {
							if settings.searchFolders.count > 1 {
								settings.searchFolders.removeAll { $0 == folder }
								settings.saveAndReindex()
							}
						}, canDelete: settings.searchFolders.count > 1
					)
				}

				addButton(title: "Add Folder") {
					folderPickerMode = .appSearch
					showingFolderPicker = true
				}

				Text("Launchable File Types")
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
					.foregroundColor(settings.secondaryTextColorUI)
					.padding(.top, DesignTokens.Spacing.xs)

				TextField(
					"app, prefPane, workflow",
					text: Binding(
						get: { settings.launcherAllowedExtensions.joined(separator: ", ") },
						set: { newValue in
							settings.launcherAllowedExtensions =
								newValue
									.split(separator: ",")
									.map { $0.trimmingCharacters(in: .whitespaces) }
									.filter { !$0.isEmpty }
							settings.scheduleSave()
						}
					)
				)
				.textFieldStyle(PlainTextFieldStyle())
				.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
				.foregroundColor(settings.textColorUI)
				.padding(.horizontal, DesignTokens.Spacing.lg)
				.padding(.vertical, DesignTokens.Spacing.md)
				.background(settings.searchBarColorUI.opacity(0.5))
				.cornerRadius(DesignTokens.CornerRadius.md)
			}

			Divider()
				.background(settings.secondaryTextColorUI.opacity(0.2))

			VStack(alignment: .leading, spacing: 8) {
				HStack {
					Text("File Search")
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
						.foregroundColor(settings.textColorUI)
					Spacer()
					Switch(
						isOn: Binding(
							get: { settings.enableFileSearch },
							set: { newValue in
								settings.enableFileSearch = newValue
								settings.scheduleSave()
								NotificationCenter.default.post(name: .refreshAppIndex, object: nil)
							}
						))
				}

				if settings.enableFileSearch {
					Text("Directories")
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(settings.secondaryTextColorUI)

					ForEach(settings.fileSearchDirectories, id: \.self) { dir in
						folderRow(
							folder: dir,
							onDelete: {
								settings.fileSearchDirectories.removeAll { $0 == dir }
								settings.scheduleSave()
								NotificationCenter.default.post(name: .refreshAppIndex, object: nil)
							}, canDelete: true
						)
					}

					addButton(title: "Add Folder") {
						folderPickerMode = .fileSearch
						showingFolderPicker = true
					}

					Text("Searchable File Types")
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(settings.secondaryTextColorUI)
						.padding(.top, DesignTokens.Spacing.xs)

					TextField(
						"txt, md, pdf, doc, docx",
						text: Binding(
							get: { settings.fileSearchExtensions.joined(separator: ", ") },
							set: { newValue in
								settings.fileSearchExtensions =
									newValue
										.split(separator: ",")
										.map { $0.trimmingCharacters(in: .whitespaces) }
										.filter { !$0.isEmpty }
								settings.scheduleSave()
								NotificationCenter.default.post(name: .refreshAppIndex, object: nil)
							}
						)
					)
					.textFieldStyle(PlainTextFieldStyle())
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
					.foregroundColor(settings.textColorUI)
					.padding(.horizontal, DesignTokens.Spacing.lg)
					.padding(.vertical, DesignTokens.Spacing.md)
					.background(settings.searchBarColorUI.opacity(0.5))
					.cornerRadius(DesignTokens.CornerRadius.md)
				}
			}
		}
	}

	private var webSearchSection: some View {
		VStack(alignment: .leading, spacing: 20) {
			HStack {
				Text("Fallback Search")
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
					.foregroundColor(settings.textColorUI)
				Spacer()
				Switch(
					isOn: Binding(
						get: { settings.enableFallbackSearch },
						set: { newValue in
							settings.enableFallbackSearch = newValue
							settings.scheduleSave()
						}
					))
			}

			if settings.enableFallbackSearch {
				VStack(alignment: .leading, spacing: 12) {
					VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
						Text("Behavior")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
							.foregroundColor(settings.textColorUI)

						RadioGroup(
							items: FallbackSearchBehavior.allCases,
							selection: Binding(
								get: { settings.fallbackSearchBehavior },
								set: { newValue in
									settings.fallbackSearchBehavior = newValue
									settings.scheduleSave()
								}
							),
							label: { $0.displayName },
							settings: settings
						)
					}

					settingsRow("Minimum Query Length") {
						RangeSlider(
							value: Binding(
								get: { Double(settings.fallbackSearchMinQueryLength) },
								set: { settings.fallbackSearchMinQueryLength = Int($0) }
							),
							range: 1 ... 5,
							step: 1,
							valueLabel: { "\(Int($0))" }
						)
					}

					settingsRow("Maximum Engines") {
						RangeSlider(
							value: Binding(
								get: { Double(settings.fallbackSearchMaxEngines) },
								set: { settings.fallbackSearchMaxEngines = Int($0) }
							),
							range: 1 ... 4,
							step: 1,
							valueLabel: { "\(Int($0))" }
						)
					}

					Divider()
						.background(settings.secondaryTextColorUI.opacity(0.2))

					VStack(alignment: .leading, spacing: 4) {
						HStack {
							Text("Search Engines")
								.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
								.foregroundColor(settings.secondaryTextColorUI)

							Spacer()

							HStack(spacing: 6) {
								SwiftUI.Button(action: {
									showingAddEngine = true
								}) {
									HStack(spacing: 4) {
										Image(systemName: "plus")
											.font(Font(settings.uiFont.withSize(10)))
										Text("Add")
											.font(
												Font(
													settings.uiFont.withSize(
														DesignTokens.Typography.small - 1)))
									}
									.foregroundColor(settings.accentColorUI)
									.padding(.horizontal, 8)
									.padding(.vertical, 4)
									.background(settings.searchBarColorUI.opacity(0.3))
									.cornerRadius(DesignTokens.CornerRadius.sm)
								}
								.buttonStyle(PlainButtonStyle())

								SwiftUI.Button(action: {
									for engine in settings.customFallbackEngines {
										let iconName = engine.iconName.replacingOccurrences(
											of: "web:", with: ""
										)
										if iconName != "globe", !iconName.isEmpty {
											WebIconDownloader.deleteIcon(forName: iconName)
										}
									}

									settings.customFallbackEngines = []
									settings.disabledDefaultEngines = []
									settings.engineKeywords = [:]
									settings.fallbackSearchEngines = ["google", "duckduckgo"]
									settings.scheduleSave()
								}) {
									HStack(spacing: 4) {
										Image(systemName: "arrow.counterclockwise")
											.font(Font(settings.uiFont.withSize(10)))
										Text("Reset")
											.font(
												Font(
													settings.uiFont.withSize(
														DesignTokens.Typography.small - 1)))
									}
									.foregroundColor(settings.secondaryTextColorUI)
									.padding(.horizontal, 8)
									.padding(.vertical, 4)
									.background(settings.searchBarColorUI.opacity(0.3))
									.cornerRadius(DesignTokens.CornerRadius.sm)
								}
								.buttonStyle(PlainButtonStyle())
							}
						}

						Text(
							"Fallback: show when no results • Bang: keyword search (e.g., \"g search term\")"
						)
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(settings.secondaryTextColorUI.opacity(0.7))
					}

					ForEach(settings.allFallbackEngines, id: \.id) { engine in
						FallbackSearchEngineCard(
							engine: engine,
							isEnabled: settings.fallbackSearchEngines.contains(engine.id),
							onToggle: {
								if settings.fallbackSearchEngines.contains(engine.id) {
									settings.fallbackSearchEngines.removeAll { $0 == engine.id }
								} else {
									settings.fallbackSearchEngines.append(engine.id)
								}
								settings.scheduleSave()
							},
							onDelete: {
								settings.removeFallbackEngine(id: engine.id)
							},
							onKeywordChange: { keyword in
								settings.updateEngineKeyword(id: engine.id, keyword: keyword)
							},
							canDelete: settings.allFallbackEngines.count > 1
						)
					}
				}
			}
		}
	}

	private func folderRow(folder: String, onDelete: @escaping () -> Void, canDelete: Bool)
		-> some View
	{
		let folderName = folder.split(separator: "/").last.map(String.init) ?? folder
		let isHomePath = folder.hasPrefix(NSHomeDirectory())
		let displayPath =
			isHomePath ? folder.replacingOccurrences(of: NSHomeDirectory(), with: "~") : folder

		return HStack(spacing: DesignTokens.Spacing.md) {
			VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
				Text(folderName)
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
					.foregroundColor(settings.textColorUI)

				Text(displayPath)
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small - 1)))
					.foregroundColor(settings.secondaryTextColorUI.opacity(0.7))
					.lineLimit(1)
			}

			Spacer()

			SwiftUI.Button(action: onDelete) {
				Image(systemName: "xmark.circle.fill")
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.icon)))
					.foregroundColor(settings.secondaryTextColorUI.opacity(canDelete ? 0.8 : 0.4))
			}
			.buttonStyle(PlainButtonStyle())
			.disabled(!canDelete)
			.help(canDelete ? "Remove" : "At least one folder required")
		}
		.padding(.horizontal, DesignTokens.Spacing.sm)
		.padding(.vertical, DesignTokens.Spacing.sm)
		.background(settings.searchBarColorUI.opacity(0.3))
		.cornerRadius(DesignTokens.CornerRadius.sm)
	}

	private func addButton(title: String, action: @escaping () -> Void) -> some View {
		SwiftUI.Button(action: action) {
			HStack(spacing: DesignTokens.Spacing.xs) {
				Image(systemName: "plus.circle")
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.iconSmall)))
				Text(title)
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
			}
			.foregroundColor(settings.accentColorUI)
			.padding(.horizontal, DesignTokens.Spacing.sm)
			.padding(.vertical, DesignTokens.Spacing.xs)
		}
		.buttonStyle(PlainButtonStyle())
	}

	private func sectionHeader(_ title: String, subtitle: String? = nil) -> some View {
		VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
			Text(title)
				.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
				.foregroundColor(settings.textColorUI)
			if let subtitle {
				Text(subtitle)
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
					.foregroundColor(settings.secondaryTextColorUI.opacity(0.8))
			}
		}
	}

	private func settingsRow(
		_ label: String,
		@ViewBuilder content: () -> some View
	) -> some View {
		HStack {
			Text(label)
				.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
				.foregroundColor(settings.textColorUI)
			Spacer()
			content()
		}
	}
}
