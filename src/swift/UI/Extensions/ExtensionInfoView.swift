import SwiftUI

struct ExtensionInfoView: View {
	let action: Action
	let onClose: () -> Void
	@ObservedObject var settings = AppSettings.shared
	@ObservedObject var actionManager = ActionManager.shared
	@State private var editingName = ""
	@State private var editingKeyword = ""
	@State private var editingDescription = ""
	@State private var editingAuthor = ""
	@State private var editingVersion = ""
	@State private var editingIcon = ""
	@State private var editingEnv: [String: String] = [:]
	@State private var newEnvKey = ""
	@State private var newEnvValue = ""
	@State private var hasChanges = false

	var body: some View {
		VStack(spacing: 0) {
			HStack(alignment: .top, spacing: 16) {
				Image(systemName: editingIcon.isEmpty ? "puzzlepiece.extension" : editingIcon)
					.font(Font(settings.uiFont.withSize(40)))
					.foregroundColor(settings.accentColorUI)

				VStack(alignment: .leading, spacing: 6) {
					HStack(spacing: DesignTokens.Spacing.md) {
						Text(editingName)
							.font(Font(NSFont.systemFont(ofSize: 18, weight: .semibold)))
							.foregroundColor(settings.textColorUI)

						if !editingVersion.isEmpty {
							Text("v\(editingVersion)")
								.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
								.foregroundColor(settings.secondaryTextColorUI)
								.padding(.horizontal, DesignTokens.Spacing.sm)
								.padding(.vertical, DesignTokens.Spacing.xxs)
								.background(settings.searchBarColorUI.opacity(0.5))
								.cornerRadius(DesignTokens.CornerRadius.sm)
						}
					}

					if !editingAuthor.isEmpty {
						Text("by \(editingAuthor)")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
							.foregroundColor(settings.secondaryTextColorUI)
					}

					if case .scriptFilter = action.kind {
						HStack(spacing: DesignTokens.Spacing.xs) {
							Image(systemName: "command")
								.font(Font(settings.uiFont.withSize(DesignTokens.Spacing.md + 2)))
							Text(editingKeyword)
								.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						}
						.foregroundColor(settings.accentColorUI.opacity(0.8))
					}
				}

				Spacer()
			}
			.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
			.background(settings.searchBarColorUI.opacity(0.3))

			Divider().background(Color.white.opacity(0.1))

			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					if case let .scriptFilter(_, scriptPath, extensionDir) = action.kind {
						FormFieldText(
							label: "Type",
							labelStyle: .uppercase,
							text: .constant("Script Filter"),
							editable: false
						)

						FormFieldText(
							label: "Name",
							labelStyle: .uppercase,
							text: $editingName,
							onChange: { hasChanges = true }
						)

						FormFieldText(
							label: "Keyword",
							labelStyle: .uppercase,
							text: $editingKeyword,
							onChange: { hasChanges = true }
						)

						FormFieldText(
							label: "Description",
							labelStyle: .uppercase,
							text: $editingDescription,
							onChange: { hasChanges = true }
						)

						FormFieldText(
							label: "Author",
							labelStyle: .uppercase,
							text: $editingAuthor,
							onChange: { hasChanges = true }
						)

						FormFieldText(
							label: "Version",
							labelStyle: .uppercase,
							text: $editingVersion,
							onChange: { hasChanges = true }
						)

						FormFieldText(
							label: "Icon (SF Symbol)",
							labelStyle: .uppercase,
							text: $editingIcon,
							onChange: { hasChanges = true }
						)

						VStack(alignment: .leading, spacing: 8) {
							Text("Environment Variables")
								.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
								.foregroundColor(settings.secondaryTextColorUI)
								.textCase(.uppercase)

							ForEach(Array(editingEnv.keys.sorted()), id: \.self) { key in
								HStack(spacing: DesignTokens.Spacing.md) {
									Text(key)
										.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
										.foregroundColor(settings.secondaryTextColorUI)
										.frame(width: 150, alignment: .leading)

									TextField("Value", text: Binding(
										get: { editingEnv[key] ?? "" },
										set: { editingEnv[key] = $0
											hasChanges = true
										}
									))
									.textFieldStyle(PlainTextFieldStyle())
									.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
									.foregroundColor(settings.textColorUI)
									.padding(DesignTokens.Spacing.md)
									.background(settings.searchBarColorUI.opacity(0.5))
									.cornerRadius(DesignTokens.CornerRadius.sm)

									SwiftUI.Button(action: {
										editingEnv.removeValue(forKey: key)
										hasChanges = true
									}) {
										Image(systemName: "minus.circle.fill")
											.foregroundColor(.red.opacity(0.8))
									}
									.buttonStyle(PlainButtonStyle())
								}
							}

							HStack(spacing: DesignTokens.Spacing.md) {
								TextField("Key", text: $newEnvKey)
									.textFieldStyle(PlainTextFieldStyle())
									.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
									.foregroundColor(settings.textColorUI)
									.padding(DesignTokens.Spacing.md)
									.frame(width: 150)
									.background(settings.searchBarColorUI.opacity(0.3))
									.cornerRadius(DesignTokens.CornerRadius.sm)

								TextField("Value", text: $newEnvValue)
									.textFieldStyle(PlainTextFieldStyle())
									.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
									.foregroundColor(settings.textColorUI)
									.padding(DesignTokens.Spacing.md)
									.background(settings.searchBarColorUI.opacity(0.3))
									.cornerRadius(DesignTokens.CornerRadius.sm)

								SwiftUI.Button(action: {
									if !newEnvKey.isEmpty {
										editingEnv[newEnvKey] = newEnvValue
										newEnvKey = ""
										newEnvValue = ""
										hasChanges = true
									}
								}) {
									Image(systemName: "plus.circle.fill")
										.foregroundColor(settings.accentColorUI)
								}
								.buttonStyle(PlainButtonStyle())
							}
						}

						FormFieldText(
							label: "Script",
							labelStyle: .uppercase,
							text: .constant(scriptPath),
							editable: false
						)
						FormFieldText(
							label: "Location",
							labelStyle: .uppercase,
							text: .constant(extensionDir),
							editable: false
						)

						Divider().background(Color.white.opacity(0.1))

						HStack(spacing: DesignTokens.Spacing.lg) {
							Button(
								"Show in Finder",
								icon: "folder",
								style: .secondary,
								size: .small,
								fullWidth: true
							) {
								NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: extensionDir)
							}

							Button(
								"Export",
								icon: "square.and.arrow.up",
								style: .secondary,
								size: .small,
								fullWidth: true
							) {
								exportExtension(extensionDir: extensionDir)
							}
						}
					}
				}
				.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
			}

			Divider().background(Color.white.opacity(0.1))

			HStack(spacing: DesignTokens.Spacing.lg) {
				if hasChanges {
					Button("Save Changes", style: .primary) {
						if case let .scriptFilter(_, scriptPath, extensionDir) = action.kind {
							saveManifest(extensionDir: extensionDir, scriptPath: scriptPath)
						}
					}
				}

				Spacer()

				Button("Close", style: .secondary) {
					onClose()
				}
			}
			.padding(DesignTokens.Spacing.xl)
			.background(settings.backgroundColorUI)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(settings.backgroundColorUI)
		.onAppear {
			loadManifest()
		}
	}

	private func loadManifest() {
		guard case let .scriptFilter(_, _, extensionDir) = action.kind,
		      let manifest = ExtensionManifest.load(from: extensionDir) else { return }

		editingName = manifest.name
		editingKeyword = manifest.keyword
		editingDescription = manifest.description ?? ""
		editingAuthor = manifest.author ?? ""
		editingVersion = manifest.version ?? "1.0.0"
		editingIcon = manifest.icon ?? "puzzlepiece.extension"
		editingEnv = manifest.env ?? [:]
	}

	private func saveManifest(extensionDir: String, scriptPath: String) {
		guard !editingName.isEmpty, !editingKeyword.isEmpty else { return }

		let manifestPath = (extensionDir as NSString).appendingPathComponent("manifest.json")
		let scriptName = (scriptPath as NSString).lastPathComponent

		var manifestDict: [String: Any] = [
			"name": editingName,
			"keyword": editingKeyword,
			"script": scriptName
		]

		if !editingDescription.isEmpty {
			manifestDict["description"] = editingDescription
		}
		if !editingAuthor.isEmpty {
			manifestDict["author"] = editingAuthor
		}
		if !editingVersion.isEmpty {
			manifestDict["version"] = editingVersion
		}
		if !editingIcon.isEmpty {
			manifestDict["icon"] = editingIcon
		}
		if !editingEnv.isEmpty {
			manifestDict["env"] = editingEnv
		}

		guard let jsonData = try? JSONSerialization.data(
			withJSONObject: manifestDict,
			options: [.prettyPrinted, .sortedKeys]
		) else { return }

		try? jsonData.write(to: URL(fileURLWithPath: manifestPath))

		var updated = action
		updated.name = editingName
		updated.icon = editingIcon
		updated.kind = .scriptFilter(keyword: editingKeyword, scriptPath: scriptPath, extensionDir: extensionDir)
		actionManager.update(updated)

		hasChanges = false
	}

	private func exportExtension(extensionDir: String) {
		guard let manifest = ExtensionManifest.load(from: extensionDir) else { return }

		let savePanel = NSSavePanel()
		savePanel.title = "Export Extension"
		savePanel.message = "Choose where to save the extension"
		savePanel.nameFieldStringValue = "\(manifest.name.replacingOccurrences(of: " ", with: "-")).summonext"
		savePanel.allowedContentTypes = [.zip]
		savePanel.canCreateDirectories = true

		savePanel.begin { response in
			guard response == .OK, let url = savePanel.url else { return }

			let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
			try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

			let extensionURL = URL(fileURLWithPath: extensionDir)
			let destURL = tempDir.appendingPathComponent(extensionURL.lastPathComponent)

			do {
				try FileManager.default.copyItem(at: extensionURL, to: destURL)

				let process = Process()
				process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
				process.arguments = ["-r", url.path, destURL.lastPathComponent]
				process.currentDirectoryURL = tempDir

				try process.run()
				process.waitUntilExit()

				try? FileManager.default.removeItem(at: tempDir)
				NSWorkspace.shared.activateFileViewerSelecting([url])
			} catch {
				print("Export failed: \(error)")
			}
		}
	}
}
