import SwiftUI

struct ExtensionsSettingsTab: View {
	@ObservedObject var settings = AppSettings.shared
	@ObservedObject var actionManager = ActionManager.shared
	@State private var selectedExtensionId: String? = nil
	@State private var showingCreateExtension = false
	@State private var lastKeyTime: Date = .init()
	@State private var pendingGKey = false
	@State private var eventMonitor: Any? = nil

	var extensions: [Action] {
		actionManager.actions.filter { action in
			switch action.kind {
			case .pattern, .scriptFilter:
				true
			case .quickLink:
				false
			}
		}
	}

	private func setupEventMonitor() {
		eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
			guard let chars = event.charactersIgnoringModifiers else {
				return event
			}
			let key = chars.lowercased()

			if event.modifierFlags.contains(.command), key == "n" {
				showingCreateExtension = true
				return nil
			}

			guard !extensions.isEmpty,
			      !showingCreateExtension,
			      NSApp.keyWindow?.firstResponder as? NSTextView == nil,
			      NSApp.keyWindow?.firstResponder as? NSTextField == nil
			else {
				return event
			}

			if event.modifierFlags.contains(.control) {
				switch key {
				case "n":
					if let currentId = selectedExtensionId,
					   let currentIndex = extensions.firstIndex(where: { $0.id == currentId }),
					   currentIndex < extensions.count - 1
					{
						selectedExtensionId = extensions[currentIndex + 1].id
					} else if selectedExtensionId == nil, !extensions.isEmpty {
						selectedExtensionId = extensions.first?.id
					}
					return nil
				case "p":
					if let currentId = selectedExtensionId,
					   let currentIndex = extensions.firstIndex(where: { $0.id == currentId }),
					   currentIndex > 0
					{
						selectedExtensionId = extensions[currentIndex - 1].id
					} else if selectedExtensionId == nil, !extensions.isEmpty {
						selectedExtensionId = extensions.last?.id
					}
					return nil
				default:
					break
				}
			}

			if pendingGKey {
				if chars == "g" {
					selectedExtensionId = extensions.first?.id
					pendingGKey = false
					return nil
				} else {
					pendingGKey = false
				}
			}

			if pendingGKey, Date().timeIntervalSince(lastKeyTime) > 0.5 {
				pendingGKey = false
			}

			guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
				return event
			}

			switch key {
			case "j":
				if let currentId = selectedExtensionId,
				   let currentIndex = extensions.firstIndex(where: { $0.id == currentId }),
				   currentIndex < extensions.count - 1
				{
					selectedExtensionId = extensions[currentIndex + 1].id
				} else if selectedExtensionId == nil, !extensions.isEmpty {
					selectedExtensionId = extensions.first?.id
				}
				return nil

			case "k":
				if let currentId = selectedExtensionId,
				   let currentIndex = extensions.firstIndex(where: { $0.id == currentId }),
				   currentIndex > 0
				{
					selectedExtensionId = extensions[currentIndex - 1].id
				} else if selectedExtensionId == nil, !extensions.isEmpty {
					selectedExtensionId = extensions.last?.id
				}
				return nil

			case "g":
				if chars == "G" {
					selectedExtensionId = extensions.last?.id
					return nil
				}
				pendingGKey = true
				lastKeyTime = Date()
				return nil

			case "h":
				selectedExtensionId = nil
				return nil

			default:
				break
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

	private func importExtension() {
		let openPanel = NSOpenPanel()
		openPanel.title = "Import Extension"
		openPanel.message = "Choose an extension package to import"
		openPanel.canChooseFiles = true
		openPanel.canChooseDirectories = false
		openPanel.allowsMultipleSelection = false
		openPanel.allowedContentTypes = [.zip]

		openPanel.begin { response in
			guard response == .OK, let url = openPanel.url else { return }

			let extensionsDir = StoragePathManager.shared.getExtensionsDir()
			let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

			do {
				try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

				let process = Process()
				process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
				process.arguments = ["-q", url.path, "-d", tempDir.path]

				try process.run()
				process.waitUntilExit()

				guard process.terminationStatus == 0 else {
					try? FileManager.default.removeItem(at: tempDir)
					print("Failed to unzip extension")
					return
				}

				let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)

				guard let extensionDir = contents.first(where: { $0.hasDirectoryPath }) else {
					try? FileManager.default.removeItem(at: tempDir)
					print("No extension directory found in package")
					return
				}

				let manifestPath = extensionDir.appendingPathComponent("manifest.json")
				guard FileManager.default.fileExists(atPath: manifestPath.path) else {
					try? FileManager.default.removeItem(at: tempDir)
					print("No manifest.json found")
					return
				}

				let destURL = URL(fileURLWithPath: extensionsDir).appendingPathComponent(extensionDir.lastPathComponent)

				if FileManager.default.fileExists(atPath: destURL.path) {
					try FileManager.default.removeItem(at: destURL)
				}

				try FileManager.default.moveItem(at: extensionDir, to: destURL)

				try? FileManager.default.removeItem(at: tempDir)

				DispatchQueue.main.async {
					actionManager.load()
				}
			} catch {
				print("Import failed: \(error)")
				try? FileManager.default.removeItem(at: tempDir)
			}
		}
	}

	var body: some View {
		HStack(spacing: 0) {
			VStack(spacing: 0) {
				HStack {
					Text("Extensions")
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.title)))
						.foregroundColor(settings.textColorUI.opacity(0.7))
					Spacer()

					HStack(spacing: DesignTokens.Spacing.lg) {
						Button(action: {
							let extensionsDir = StoragePathManager.shared.getExtensionsDir()
							NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: extensionsDir)
						}) {
							Image(systemName: "folder")
								.font(.system(size: DesignTokens.Typography.body))
								.foregroundColor(settings.secondaryTextColorUI)
						}
						.buttonStyle(PlainButtonStyle())
						.help("Open extensions folder")

						Button(action: importExtension) {
							Image(systemName: "square.and.arrow.down")
								.font(.system(size: DesignTokens.Typography.body))
								.foregroundColor(settings.secondaryTextColorUI)
						}
						.buttonStyle(PlainButtonStyle())
						.help("Import extension")

						Button(action: { showingCreateExtension = true }) {
							Image(systemName: "plus")
								.font(.system(size: DesignTokens.Typography.body))
								.foregroundColor(settings.accentColorUI)
						}
						.buttonStyle(PlainButtonStyle())
						.help("Create extension")
					}
				}
				.padding(.horizontal, DesignTokens.Spacing.xl)
				.padding(.vertical, DesignTokens.Spacing.lg)
				.background(settings.backgroundColorUI)

				Divider().background(Color.white.opacity(0.1))

				if extensions.isEmpty {
					VStack(spacing: DesignTokens.Spacing.lg) {
						Spacer()
						Image(systemName: "puzzlepiece.extension")
							.font(.system(size: 32))
							.foregroundColor(settings.secondaryTextColorUI.opacity(0.4))
						Text("No extensions yet")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
							.foregroundColor(settings.secondaryTextColorUI)
						Button(action: {
							showingCreateExtension = true
						}) {
							HStack(spacing: DesignTokens.Spacing.sm) {
								Image(systemName: "plus.circle.fill")
									.font(.system(size: DesignTokens.Typography.title))
								Text("Create Extension")
									.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
							}
							.foregroundColor(settings.accentColorUI)
							.padding(.horizontal, DesignTokens.Spacing.xl)
							.padding(.vertical, DesignTokens.Spacing.md + 2)
							.background(settings.searchBarColorUI)
							.cornerRadius(DesignTokens.CornerRadius.md)
						}
						.buttonStyle(PlainButtonStyle())
						Spacer()
					}
					.frame(maxWidth: .infinity)
				} else {
					ScrollView {
						VStack(spacing: DesignTokens.Spacing.xs) {
							ForEach(extensions) { ext in
								ExtensionListItem(
									action: ext,
									isSelected: selectedExtensionId == ext.id,
									onSelect: { selectedExtensionId = ext.id },
									onDelete: {
										actionManager.remove(ext)
										if selectedExtensionId == ext.id {
											selectedExtensionId = nil
										}
									}
								)
							}
						}
						.padding(DesignTokens.Spacing.md)
					}
				}
			}
			.frame(width: 280)
			.background(settings.backgroundColorUI)

			Divider().background(Color.white.opacity(0.1))

			Group {
				if let selectedId = selectedExtensionId,
				   let selectedExtension = extensions.first(where: { $0.id == selectedId })
				{
					ExtensionInfoView(
						action: selectedExtension,
						onClose: { selectedExtensionId = nil }
					)
					.id(selectedExtension.id)
				} else {
					VStack(spacing: DesignTokens.Spacing.xl) {
						Image(systemName: "puzzlepiece.extension")
							.font(.system(size: 64))
							.foregroundColor(settings.secondaryTextColorUI.opacity(0.3))
						Text("Select an extension to view details")
							.font(Font(settings.uiFont.withSize(15)))
							.foregroundColor(settings.secondaryTextColorUI)
						Text("Extensions are managed via manifest.json files")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
							.foregroundColor(settings.secondaryTextColorUI.opacity(0.6))
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.background(settings.backgroundColorUI)
				}
			}
		}
		.sheet(isPresented: $showingCreateExtension) {
			ExtensionCreator()
		}
		.onAppear {
			setupEventMonitor()
		}
		.onDisappear {
			removeEventMonitor()
		}
	}
}

struct ExtensionListItem: View {
	let action: Action
	let isSelected: Bool
	let onSelect: () -> Void
	let onDelete: () -> Void
	@ObservedObject var settings = AppSettings.shared
	@State private var isHovered = false

	var body: some View {
		HStack(spacing: DesignTokens.Spacing.md + 2) {
			Image(systemName: action.icon.isEmpty ? "puzzlepiece.extension" : action.icon)
				.font(.system(size: DesignTokens.Typography.title))
				.foregroundColor(isSelected ? settings.accentColorUI : settings.textColorUI)
				.frame(width: 20)

			Button(action: {
				onSelect()
			}) {
				VStack(alignment: .leading, spacing: 2) {
					Text(action.name)
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(isSelected ? settings.accentColorUI : settings.textColorUI)
						.lineLimit(1)
				}
			}
			.buttonStyle(PlainButtonStyle())

			Spacer()

			if isHovered {
				Button(action: {
					onDelete()
				}) {
					Image(systemName: "trash")
						.font(.system(size: DesignTokens.Typography.small))
						.foregroundColor(.red.opacity(0.7))
				}
				.buttonStyle(PlainButtonStyle())
			}
		}
		.padding(.horizontal, DesignTokens.Spacing.lg)
		.padding(.vertical, DesignTokens.Spacing.md)
		.background(isSelected ? settings.accentColorUI
			.opacity(0.15) : (isHovered ? settings.searchBarColorUI.opacity(0.5) : Color.clear))
		.cornerRadius(DesignTokens.CornerRadius.md)
		.onHover { hovering in
			isHovered = hovering
		}
	}
}
