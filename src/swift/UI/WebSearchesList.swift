import SwiftUI

struct WebSearchesList: View {
	@ObservedObject var settings = AppSettings.shared
	@ObservedObject var actionManager = ActionManager.shared
	@State private var showingAddSearch = false

	var quickLinks: [Action] {
		actionManager.actions.filter { action in
			if case .quickLink = action.kind {
				return true
			}
			return false
		}
	}

	private func hasConflict(_ action: Action) -> Bool {
		guard case .quickLink(let keyword, _) = action.kind else { return false }
		return quickLinks.filter {
			if case .quickLink(let k, _) = $0.kind {
				return k == keyword && $0.enabled
			}
			return false
		}.count > 1
	}

	var body: some View {
		ScrollView {
			VStack(spacing: 8) {
				ForEach(quickLinks) { action in
					InlineEditableWebSearchCard(
						action: action,
						hasConflict: hasConflict(action),
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

				Button(action: { showingAddSearch = true }) {
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
					.frame(maxWidth: .infinity)
					.background(settings.searchBarColorUI.opacity(0.3))
					.cornerRadius(6)
				}
				.buttonStyle(PlainButtonStyle())
			}
			.padding(24)
		}
		.sheet(isPresented: $showingAddSearch) {
			AddActionView()
		}
	}
}

struct InlineEditableWebSearchCard: View {
	let action: Action
	let hasConflict: Bool
	let onUpdate: (Action) -> Void
	let onToggle: () -> Void
	let onDelete: () -> Void
	@ObservedObject var settings = AppSettings.shared
	@State private var isHovered = false
	@State private var editingKeyword = ""
	@State private var editingURL = ""
	@State private var isEditingKeyword = false
	@State private var isEditingURL = false
	@State private var brandIcon: NSImage?
	@FocusState private var keywordFocused: Bool
	@FocusState private var urlFocused: Bool

	var body: some View {
		guard case .quickLink(let keyword, let url) = action.kind else {
			return AnyView(EmptyView())
		}

		return AnyView(
			HStack(spacing: 12) {
				Switch(
					isOn: Binding(
						get: { action.enabled },
						set: { _ in onToggle() }
					)
				)
				.frame(width: 40)

				if let icon = brandIcon {
					Image(nsImage: icon)
						.resizable()
						.frame(width: 20, height: 20)
						.opacity(action.enabled ? 1.0 : 0.5)
				} else {
					Image(systemName: action.icon.isEmpty ? "globe" : action.icon)
						.font(.system(size: 14))
						.foregroundColor(
							action.enabled
								? settings.accentColorUI : settings.secondaryTextColorUI.opacity(0.5)
						)
						.frame(width: 20)
				}

				Group {
					if isEditingKeyword {
						TextField("Keyword", text: $editingKeyword, onEditingChanged: { _ in })
							.textFieldStyle(PlainTextFieldStyle())
							.font(Font(settings.uiFont.withSize(13)))
							.foregroundColor(settings.accentColorUI)
							.focused($keywordFocused)
							.onSubmit {
								saveKeyword()
							}
							.frame(width: 80)
					} else {
						Text(keyword)
							.font(Font(settings.uiFont.withSize(13)))
							.foregroundColor(settings.accentColorUI)
							.frame(width: 80, alignment: .leading)
							.onTapGesture {
								startEditingKeyword(keyword)
							}
					}
				}
				.padding(.horizontal, 10)
				.padding(.vertical, 6)
				.background(settings.searchBarColorUI)
				.cornerRadius(6)

				Image(systemName: "arrow.right")
					.font(.system(size: 10))
					.foregroundColor(settings.secondaryTextColorUI)

				if hasConflict, action.enabled {
					Image(systemName: "exclamationmark.triangle.fill")
						.font(.system(size: 12))
						.foregroundColor(Color.orange)
						.help("Duplicate keyword detected")
				}

				Group {
					if isEditingURL {
						TextField("URL", text: $editingURL, onEditingChanged: { _ in })
							.textFieldStyle(PlainTextFieldStyle())
							.font(Font(settings.uiFont.withSize(13)))
							.foregroundColor(settings.textColorUI)
							.focused($urlFocused)
							.onSubmit {
								saveURL()
							}
					} else {
						Text(url)
							.font(Font(settings.uiFont.withSize(13)))
							.foregroundColor(settings.textColorUI)
							.lineLimit(1)
							.truncationMode(.middle)
							.onTapGesture {
								startEditingURL(url)
							}
					}
				}

				Spacer()

				Button(action: onDelete) {
					Image(systemName: "trash")
						.font(.system(size: 12))
						.foregroundColor(Color.red.opacity(isHovered ? 0.8 : 0.4))
						.frame(width: 24, height: 24)
				}
				.buttonStyle(PlainButtonStyle())
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.background(settings.searchBarColorUI.opacity(isHovered ? 0.8 : 0.3))
			.cornerRadius(6)
			.onHover { hovering in
				isHovered = hovering
			}
			.onAppear {
				loadBrandIcon(url: url)
			}
		)
	}

	private func loadBrandIcon(url: String) {
		// Check if it's a file path (absolute path or starts with ~)
		if action.icon.hasPrefix("/") || action.icon.hasPrefix("~") {
			let expandedPath = NSString(string: action.icon).expandingTildeInPath
			if FileManager.default.fileExists(atPath: expandedPath),
			   let image = NSImage(contentsOfFile: expandedPath)
			{
				// Resize to 20x20
				let size = NSSize(width: 20, height: 20)
				let resized = NSImage(size: size)
				resized.lockFocus()
				NSGraphicsContext.current?.imageInterpolation = .high
				image.draw(
					in: NSRect(origin: .zero, size: size),
					from: NSRect(origin: .zero, size: image.size),
					operation: .copy,
					fraction: 1.0
				)
				resized.unlockFocus()
				brandIcon = resized
				return
			}
		}

		// Check if it's a web icon (e.g., "web:google")
		if action.icon.hasPrefix("web:") {
			let iconName = String(action.icon.dropFirst(4)) // Remove "web:" prefix
			let actionName = action.name
			let actionIcon = action.icon

			// Use on-demand downloader
			WebIconDownloader.getIcon(for: iconName, size: NSSize(width: 20, height: 20)) { image in
				DispatchQueue.main.async {
					if let image {
						self.brandIcon = image
					} else {
						// Fallback to generated icon
						self.brandIcon = ActionIconGenerator.generateIcon(
							for: actionName,
							iconName: actionIcon,
							url: url
						)
					}
				}
			}
			return
		}

		// Fallback to generated icon
		brandIcon = ActionIconGenerator.generateIcon(for: action.name, iconName: action.icon, url: url)
	}

	private func startEditingKeyword(_ keyword: String) {
		editingKeyword = keyword
		isEditingKeyword = true
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
			keywordFocused = true
		}
	}

	private func saveKeyword() {
		isEditingKeyword = false
		guard case .quickLink(_, let url) = action.kind else { return }
		if !editingKeyword.isEmpty, editingKeyword != action.kind.keyword {
			var updated = action
			updated.kind = .quickLink(keyword: editingKeyword, url: url)
			onUpdate(updated)
		}
	}

	private func startEditingURL(_ url: String) {
		editingURL = url
		isEditingURL = true
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
			urlFocused = true
		}
	}

	private func saveURL() {
		isEditingURL = false
		guard case .quickLink(let keyword, _) = action.kind else { return }
		if !editingURL.isEmpty, editingURL != action.kind.url {
			var updated = action
			updated.kind = .quickLink(keyword: keyword, url: editingURL)
			onUpdate(updated)
		}
	}
}

extension Action.ActionKind {
	var keyword: String? {
		switch self {
		case .quickLink(let keyword, _):
			keyword
		case .scriptFilter(let keyword, _, _):
			keyword
		case .nativeExtension(let keyword, _):
			keyword
		default:
			nil
		}
	}

	var url: String? {
		switch self {
		case .quickLink(_, let url):
			url
		default:
			nil
		}
	}
}
