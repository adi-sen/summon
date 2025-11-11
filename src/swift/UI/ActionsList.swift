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
				case .pattern, .scriptFilter, .nativeExtension:
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
				SimpleExtensionCreator()
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

			case let .nativeExtension(keyword, extensionId):
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

					Text(extensionId)
						.font(Font(settings.uiFont.withSize(11)))
						.foregroundColor(settings.secondaryTextColorUI)
						.lineLimit(1)
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

				VStack(alignment: .leading, spacing: 6) {
					Text("Icon (SF Symbol)")
						.font(Font(settings.uiFont.withSize(12)))
						.foregroundColor(settings.textColorUI)
					TextField("e.g., globe", text: $icon)
						.textFieldStyle(PlainTextFieldStyle())
						.font(Font(settings.uiFont.withSize(13)))
						.foregroundColor(settings.textColorUI)
						.padding(10)
						.background(settings.searchBarColorUI)
						.cornerRadius(6)
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
						let id = UUID().uuidString
						actionManager.addQuickLink(id: id, name: name, keyword: keyword, url: url, icon: icon)
						presentationMode.wrappedValue.dismiss()
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
		.frame(width: 480, height: 440)
		.background(settings.backgroundColorUI)
	}
}
