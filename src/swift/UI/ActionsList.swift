import SwiftUI

enum ActionFilterType {
	case all
	case quickLink
	case extensions
}

struct ActionsList: View {
	@ObservedObject var settings = AppSettings.shared
	@ObservedObject var actionManager = ActionManager.shared
	@State private var showingAddAction = false

	let filterType: ActionFilterType

	init(filterType: ActionFilterType = .all) {
		self.filterType = filterType
	}

	var filteredActions: [Action] {
		switch filterType {
		case .all:
			actionManager.actions
		case .quickLink:
			actionManager.actions.filter { action in
				if case .quickLink = action.kind {
					return true
				}
				return false
			}
		case .extensions:
			actionManager.actions.filter { action in
				switch action.kind {
				case .pattern, .scriptFilter:
					true
				case .quickLink:
					false
				}
			}
		}
	}

	var body: some View {
		ScrollView {
			VStack(spacing: 6) {
				ForEach(filteredActions) { action in
					InlineEditableActionCard(
						action: action,
						onUpdate: { updated in
							actionManager.update(updated)
						},
						onToggle: {
							actionManager.toggle(action)
						},
						onDelete: {
							actionManager.remove(action)
						}
					)
				}

				HStack(spacing: 8) {
					if filterType == .quickLink {
						Button(action: { showingAddAction = true }) {
							HStack(spacing: 8) {
								Image(systemName: "plus.circle.fill")
									.font(.system(size: 14))
								Text("Add Web Search")
									.font(Font(settings.uiFont.withSize(13)))
							}
							.foregroundColor(settings.accentColorUI)
							.padding(.horizontal, 12)
							.padding(.vertical, 10)
							.frame(maxWidth: .infinity)
							.background(settings.searchBarColorUI.opacity(0.3))
							.cornerRadius(6)
							.overlay(
								RoundedRectangle(cornerRadius: 6)
									.strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
									.foregroundColor(settings.accentColorUI.opacity(0.3))
							)
						}
						.buttonStyle(PlainButtonStyle())
						.keyboardShortcut("n", modifiers: .command)

						Button(action: { actionManager.importDefaults() }) {
							HStack(spacing: 6) {
								Image(systemName: "arrow.counterclockwise")
									.font(.system(size: 12))
								Text("Reset to Defaults")
									.font(Font(settings.uiFont.withSize(12)))
							}
							.foregroundColor(settings.secondaryTextColorUI)
							.padding(.horizontal, 10)
							.padding(.vertical, 10)
							.background(settings.searchBarColorUI.opacity(0.3))
							.cornerRadius(6)
						}
						.buttonStyle(PlainButtonStyle())
					} else if filterType == .extensions {
						Button(action: { showingAddAction = true }) {
							HStack(spacing: 8) {
								Image(systemName: "square.and.pencil")
									.font(.system(size: 14))
								Text("Create Extension")
									.font(Font(settings.uiFont.withSize(13)))
							}
							.foregroundColor(settings.accentColorUI)
							.padding(.horizontal, 12)
							.padding(.vertical, 10)
							.frame(maxWidth: .infinity)
							.background(settings.searchBarColorUI.opacity(0.3))
							.cornerRadius(6)
							.overlay(
								RoundedRectangle(cornerRadius: 6)
									.strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
									.foregroundColor(settings.accentColorUI.opacity(0.3))
							)
						}
						.buttonStyle(PlainButtonStyle())
						.keyboardShortcut("n", modifiers: .command)
					}
				}
			}
			.padding(24)
		}
		.sheet(isPresented: $showingAddAction) {
			if filterType == .extensions {
				ExtensionCreator()
			} else {
				AddActionView()
			}
		}
	}
}

struct InlineEditableActionCard: View {
	let action: Action
	let onUpdate: (Action) -> Void
	let onToggle: () -> Void
	let onDelete: () -> Void
	@ObservedObject var settings = AppSettings.shared
	@State private var isHovered = false
	@State private var editingName = ""
	@State private var editingKeyword = ""
	@State private var editingURL = ""
	@State private var isEditingName = false
	@State private var isEditingKeyword = false
	@State private var isEditingURL = false
	@FocusState private var nameFocused: Bool
	@FocusState private var keywordFocused: Bool
	@FocusState private var urlFocused: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(spacing: 10) {
				Switch(isOn: Binding(
					get: { action.enabled },
					set: { _ in onToggle() }
				))
				.frame(width: 36)

				Image(systemName: action.icon.isEmpty ? "bolt.circle" : action.icon)
					.font(.system(size: 13))
					.foregroundColor(action.enabled ? settings.accentColorUI : settings.secondaryTextColorUI)
					.frame(width: 18)

				Group {
					if isEditingName {
						TextField("Name", text: $editingName)
							.textFieldStyle(PlainTextFieldStyle())
							.font(Font(settings.uiFont.withSize(12)))
							.foregroundColor(settings.textColorUI)
							.focused($nameFocused)
							.onSubmit { saveName() }
					} else {
						Text(action.name)
							.font(Font(settings.uiFont.withSize(12)))
							.foregroundColor(settings.textColorUI)
							.onTapGesture { startEditingName() }
					}
				}

				Spacer()

				Button(action: onDelete) {
					Image(systemName: "trash")
						.font(.system(size: 11))
						.foregroundColor(Color.red.opacity(isHovered ? 0.8 : 0.4))
						.frame(width: 20, height: 20)
				}
				.buttonStyle(PlainButtonStyle())
			}

			switch action.kind {
			case let .quickLink(keyword, url):
				HStack(spacing: 6) {
					Group {
						if isEditingKeyword {
							TextField("Keyword", text: $editingKeyword)
								.textFieldStyle(PlainTextFieldStyle())
								.font(Font(settings.uiFont.withSize(11)))
								.foregroundColor(settings.accentColorUI)
								.focused($keywordFocused)
								.onSubmit { saveKeyword() }
								.frame(width: 80)
						} else {
							Text(keyword)
								.font(Font(settings.uiFont.withSize(11)))
								.foregroundColor(settings.accentColorUI)
								.frame(width: 80, alignment: .leading)
								.onTapGesture { startEditingKeyword(keyword) }
						}
					}
					.padding(.horizontal, 6)
					.padding(.vertical, 3)
					.background(settings.searchBarColorUI)
					.cornerRadius(3)

					Image(systemName: "arrow.right")
						.font(.system(size: 8))
						.foregroundColor(settings.secondaryTextColorUI)

					Group {
						if isEditingURL {
							TextField("URL", text: $editingURL)
								.textFieldStyle(PlainTextFieldStyle())
								.font(Font(settings.uiFont.withSize(11)))
								.foregroundColor(settings.secondaryTextColorUI)
								.focused($urlFocused)
								.onSubmit { saveURL() }
						} else {
							Text(url)
								.font(Font(settings.uiFont.withSize(11)))
								.foregroundColor(settings.secondaryTextColorUI)
								.lineLimit(1)
								.truncationMode(.middle)
								.onTapGesture { startEditingURL(url) }
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
				.padding(.leading, 44)

			case let .pattern(pattern, url):
				HStack(spacing: 6) {
					Text(pattern)
						.font(Font(settings.uiFont.withSize(11)))
						.foregroundColor(settings.accentColorUI)
						.padding(.horizontal, 6)
						.padding(.vertical, 3)
						.background(settings.searchBarColorUI)
						.cornerRadius(3)

					Image(systemName: "arrow.right")
						.font(.system(size: 8))
						.foregroundColor(settings.secondaryTextColorUI)

					Text(url)
						.font(Font(settings.uiFont.withSize(11)))
						.foregroundColor(settings.secondaryTextColorUI)
						.lineLimit(1)
						.truncationMode(.middle)
				}
				.padding(.leading, 44)

			case let .scriptFilter(keyword, scriptPath, _):
				HStack(spacing: 6) {
					Text(keyword)
						.font(Font(settings.uiFont.withSize(11)))
						.foregroundColor(settings.accentColorUI)
						.padding(.horizontal, 6)
						.padding(.vertical, 3)
						.background(settings.searchBarColorUI)
						.cornerRadius(3)

					Image(systemName: "arrow.right")
						.font(.system(size: 8))
						.foregroundColor(settings.secondaryTextColorUI)

					Text(scriptPath.split(separator: "/").last.map(String.init) ?? scriptPath)
						.font(Font(settings.uiFont.withSize(11)))
						.foregroundColor(settings.secondaryTextColorUI)
						.lineLimit(1)
						.truncationMode(.middle)
				}
				.padding(.leading, 44)
			}
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
		.background(settings.searchBarColorUI.opacity(isHovered ? 0.8 : 0.3))
		.cornerRadius(5)
		.onHover { hovering in
			isHovered = hovering
		}
	}

	private func startEditingName() {
		editingName = action.name
		isEditingName = true
		nameFocused = true
	}

	private func saveName() {
		isEditingName = false
		if !editingName.isEmpty, editingName != action.name {
			var updated = action
			updated.name = editingName
			onUpdate(updated)
		}
	}

	private func startEditingKeyword(_ keyword: String) {
		editingKeyword = keyword
		isEditingKeyword = true
		keywordFocused = true
	}

	private func saveKeyword() {
		isEditingKeyword = false
		guard case let .quickLink(_, url) = action.kind else { return }
		if !editingKeyword.isEmpty {
			var updated = action
			updated.kind = .quickLink(keyword: editingKeyword, url: url)
			onUpdate(updated)
		}
	}

	private func startEditingURL(_ url: String) {
		editingURL = url
		isEditingURL = true
		urlFocused = true
	}

	private func saveURL() {
		isEditingURL = false
		guard case let .quickLink(keyword, _) = action.kind else { return }
		if !editingURL.isEmpty {
			var updated = action
			updated.kind = .quickLink(keyword: keyword, url: editingURL)
			onUpdate(updated)
		}
	}
}

struct AddActionView: View {
	@Environment(\.presentationMode) var presentationMode
	@ObservedObject var settings = AppSettings.shared
	@ObservedObject var actionManager = ActionManager.shared

	@State private var name = ""
	@State private var keyword = ""
	@State private var url = ""
	@State private var icon = "globe"
	@State private var customIconImage: NSImage?
	@State private var customIconPath: String?
	@State private var useCustomIcon = false

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Add Web Search")
					.font(Font(settings.uiFont.withSize(16)))
					.foregroundColor(settings.textColorUI)
				Spacer()
				Button(action: { presentationMode.wrappedValue.dismiss() }) {
					Image(systemName: "xmark.circle.fill")
						.font(.system(size: 18))
						.foregroundColor(settings.secondaryTextColorUI)
				}
				.buttonStyle(PlainButtonStyle())
			}
			.padding(16)
			.background(settings.backgroundColorUI)

			Divider().background(Color.white.opacity(0.1))

			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					VStack(alignment: .leading, spacing: 6) {
						Text("Name")
							.font(Font(settings.uiFont.withSize(12)))
							.foregroundColor(settings.textColorUI)
						TextField("e.g., Google Search", text: $name)
							.textFieldStyle(PlainTextFieldStyle())
							.font(Font(settings.uiFont.withSize(13)))
							.foregroundColor(settings.textColorUI)
							.padding(10)
							.background(settings.searchBarColorUI)
							.cornerRadius(6)
					}

					VStack(alignment: .leading, spacing: 6) {
						Text("Keyword")
							.font(Font(settings.uiFont.withSize(12)))
							.foregroundColor(settings.textColorUI)
						TextField("e.g., g", text: $keyword)
							.textFieldStyle(PlainTextFieldStyle())
							.font(Font(settings.uiFont.withSize(13)))
							.foregroundColor(settings.textColorUI)
							.padding(10)
							.background(settings.searchBarColorUI)
							.cornerRadius(6)
					}

					VStack(alignment: .leading, spacing: 6) {
						Text("URL (use {query} for search term)")
							.font(Font(settings.uiFont.withSize(12)))
							.foregroundColor(settings.textColorUI)
						TextField("e.g., https://google.com/search?q={query}", text: $url)
							.textFieldStyle(PlainTextFieldStyle())
							.font(Font(settings.uiFont.withSize(13)))
							.foregroundColor(settings.textColorUI)
							.padding(10)
							.background(settings.searchBarColorUI)
							.cornerRadius(6)
					}

					VStack(alignment: .leading, spacing: 10) {
						Text("Icon")
							.font(Font(settings.uiFont.withSize(12)))
							.foregroundColor(settings.textColorUI)

						HStack(spacing: 12) {
							Button(action: { useCustomIcon = false }) {
								HStack(spacing: 8) {
									Image(systemName: useCustomIcon ? "circle" : "circle.fill")
										.font(.system(size: 12))
									Text("SF Symbol")
										.font(Font(settings.uiFont.withSize(12)))
								}
								.foregroundColor(settings.textColorUI)
								.padding(.horizontal, 12)
								.padding(.vertical, 8)
								.background(
									useCustomIcon
										? settings.searchBarColorUI.opacity(0.5)
										: settings.accentColorUI.opacity(0.2)
								)
								.cornerRadius(6)
							}
							.buttonStyle(PlainButtonStyle())

							Button(action: { useCustomIcon = true }) {
								HStack(spacing: 8) {
									Image(systemName: useCustomIcon ? "circle.fill" : "circle")
										.font(.system(size: 12))
									Text("Upload Image")
										.font(Font(settings.uiFont.withSize(12)))
								}
								.foregroundColor(settings.textColorUI)
								.padding(.horizontal, 12)
								.padding(.vertical, 8)
								.background(
									useCustomIcon
										? settings.accentColorUI.opacity(0.2)
										: settings.searchBarColorUI.opacity(0.5)
								)
								.cornerRadius(6)
							}
							.buttonStyle(PlainButtonStyle())
						}

						if useCustomIcon {
							VStack(alignment: .leading, spacing: 8) {
								HStack(spacing: 12) {
									if let customImage = customIconImage {
										Image(nsImage: customImage)
											.resizable()
											.interpolation(.high)
											.frame(width: 32, height: 32)
											.background(Color.white.opacity(0.1))
											.cornerRadius(6)
									} else {
										RoundedRectangle(cornerRadius: 6)
											.fill(settings.searchBarColorUI)
											.frame(width: 32, height: 32)
											.overlay(
												Image(systemName: "photo.badge.plus")
													.font(.system(size: 14))
													.foregroundColor(settings.secondaryTextColorUI)
											)
									}

									Button(action: { selectImage() }) {
										HStack(spacing: 6) {
											Image(systemName: "photo")
												.font(.system(size: 12))
											Text(customIconImage == nil ? "Choose Image" : "Change Image")
												.font(Font(settings.uiFont.withSize(12)))
										}
										.foregroundColor(settings.accentColorUI)
										.padding(.horizontal, 12)
										.padding(.vertical, 8)
										.background(settings.searchBarColorUI)
										.cornerRadius(6)
									}
									.buttonStyle(PlainButtonStyle())

									if customIconImage != nil {
										Button(action: { clearCustomIcon() }) {
											Text("Remove")
												.font(Font(settings.uiFont.withSize(12)))
												.foregroundColor(Color.red)
												.padding(.horizontal, 12)
												.padding(.vertical, 8)
												.background(settings.searchBarColorUI)
												.cornerRadius(6)
										}
										.buttonStyle(PlainButtonStyle())
									}
								}

								Text("Supports PNG, JPG, GIF • Large images will be resized")
									.font(Font(settings.uiFont.withSize(10)))
									.foregroundColor(settings.secondaryTextColorUI.opacity(0.6))
							}
							.padding(12)
							.background(settings.searchBarColorUI.opacity(0.3))
							.cornerRadius(6)
						} else {
							HStack(spacing: 12) {
								Image(systemName: icon.isEmpty ? "globe" : icon)
									.font(.system(size: 20))
									.foregroundColor(settings.accentColorUI)
									.frame(width: 32, height: 32)
									.background(settings.searchBarColorUI.opacity(0.3))
									.cornerRadius(6)

								TextField("e.g., globe, magnifyingglass, star.fill", text: $icon)
									.textFieldStyle(PlainTextFieldStyle())
									.font(Font(settings.uiFont.withSize(13)))
									.foregroundColor(settings.textColorUI)
									.padding(10)
									.background(settings.searchBarColorUI)
									.cornerRadius(6)
							}
						}
					}

					HStack(spacing: 10) {
						Spacer()
						Button("Cancel") {
							presentationMode.wrappedValue.dismiss()
						}
						.buttonStyle(PlainButtonStyle())
						.foregroundColor(settings.textColorUI)
						.padding(.horizontal, 16)
						.padding(.vertical, 8)
						.background(settings.searchBarColorUI)
						.cornerRadius(6)

						Button("Add") {
							addWebSearch()
						}
						.buttonStyle(PlainButtonStyle())
						.foregroundColor(Color.white)
						.padding(.horizontal, 16)
						.padding(.vertical, 8)
						.background(settings.accentColorUI)
						.cornerRadius(6)
						.disabled(name.isEmpty || keyword.isEmpty || url.isEmpty)
						.opacity(name.isEmpty || keyword.isEmpty || url.isEmpty ? 0.5 : 1.0)
					}
					.padding(.top, 4)
				}
				.padding(24)
			}
		}
		.frame(width: 520, height: 520)
		.background(settings.backgroundColorUI)
	}

	private func selectImage() {
		let panel = NSOpenPanel()
		panel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff]
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.message = "Select an icon image"

		if panel.runModal() == .OK, let url = panel.url {
			if let image = NSImage(contentsOf: url) {
				customIconImage = resizeImage(image, targetSize: NSSize(width: 32, height: 32))
				customIconPath = saveCustomIcon(customIconImage!)
			}
		}
	}

	private func clearCustomIcon() {
		customIconImage = nil
		if let path = customIconPath {
			try? FileManager.default.removeItem(atPath: path)
			customIconPath = nil
		}
	}

	private func resizeImage(_ image: NSImage, targetSize: NSSize) -> NSImage {
		guard
			let imageData = image.tiffRepresentation,
			let bitmap = NSBitmapImageRep(data: imageData)
		else {
			return image
		}

		let sourceSize = NSSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
		let widthRatio = targetSize.width / sourceSize.width
		let heightRatio = targetSize.height / sourceSize.height
		let scaleFactor = min(widthRatio, heightRatio)

		let scaledSize = NSSize(
			width: sourceSize.width * scaleFactor,
			height: sourceSize.height * scaleFactor
		)

		let resized = NSImage(size: targetSize)
		resized.lockFocus()

		NSColor.clear.setFill()
		NSRect(origin: .zero, size: targetSize).fill()

		NSGraphicsContext.current?.imageInterpolation = .high

		let xOffset = (targetSize.width - scaledSize.width) / 2
		let yOffset = (targetSize.height - scaledSize.height) / 2

		image.draw(
			in: NSRect(x: xOffset, y: yOffset, width: scaledSize.width, height: scaledSize.height),
			from: NSRect(origin: .zero, size: image.size),
			operation: .sourceOver,
			fraction: 1.0
		)

		resized.unlockFocus()
		return resized
	}

	private func saveCustomIcon(_ image: NSImage) -> String? {
		let customIconsDir =
			"\(NSHomeDirectory())/Library/Application Support/Summon/CustomIcons"

		try? FileManager.default.createDirectory(
			atPath: customIconsDir,
			withIntermediateDirectories: true,
			attributes: nil
		)

		let iconId = UUID().uuidString
		let iconPath = "\(customIconsDir)/\(iconId).png"

		guard
			let tiffData = image.tiffRepresentation,
			let bitmapImage = NSBitmapImageRep(data: tiffData),
			let pngData = bitmapImage.representation(using: .png, properties: [:])
		else {
			return nil
		}

		try? pngData.write(to: URL(fileURLWithPath: iconPath))
		return iconPath
	}

	private func addWebSearch() {
		let id = UUID().uuidString
		let finalIcon: String = if useCustomIcon, let path = customIconPath {
			path
		} else {
			icon
		}

		actionManager.addQuickLink(
			id: id,
			name: name,
			keyword: keyword,
			url: url,
			icon: finalIcon
		)
		presentationMode.wrappedValue.dismiss()
	}
}
