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

				SwiftUI.Button(action: { showingAddSearch = true }) {
					HStack(spacing: 8) {
						Image(systemName: "plus.circle.fill")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.title)))
						Text("Add Web Search")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
					}
					.foregroundColor(settings.accentColorUI)
					.padding(.horizontal, 12)
					.padding(.vertical, 10)
					.frame(maxWidth: .infinity)
					.background(settings.searchBarColorUI.opacity(0.3))
					.cornerRadius(DesignTokens.CornerRadius.md)
					.overlay(
						RoundedRectangle(cornerRadius: 6)
							.strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
							.foregroundColor(settings.accentColorUI.opacity(0.3))
					)
				}
				.buttonStyle(PlainButtonStyle())
				.newItemShortcut()

				SwiftUI.Button(action: { actionManager.importDefaults() }) {
					HStack(spacing: 6) {
						Image(systemName: "arrow.counterclockwise")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						Text("Reset to Defaults")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
					}
					.foregroundColor(settings.secondaryTextColorUI)
					.padding(.horizontal, 10)
					.padding(.vertical, 10)
					.frame(maxWidth: .infinity)
					.background(settings.searchBarColorUI.opacity(0.3))
					.cornerRadius(DesignTokens.CornerRadius.md)
				}
				.buttonStyle(PlainButtonStyle())
			}
			.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
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
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.title)))
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
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
							.foregroundColor(settings.accentColorUI)
							.focused($keywordFocused)
							.onSubmit {
								saveKeyword()
							}
							.frame(width: 80)
					} else {
						Text(keyword)
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
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
				.cornerRadius(DesignTokens.CornerRadius.md)

				Image(systemName: "arrow.right")
					.font(Font(settings.uiFont.withSize(DesignTokens.Spacing.md + 2)))
					.foregroundColor(settings.secondaryTextColorUI)

				if hasConflict, action.enabled {
					Image(systemName: "exclamationmark.triangle.fill")
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(Color.orange)
						.help("Duplicate keyword detected")
				}

				Group {
					if isEditingURL {
						TextField("URL", text: $editingURL, onEditingChanged: { _ in })
							.textFieldStyle(PlainTextFieldStyle())
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
							.foregroundColor(settings.textColorUI)
							.focused($urlFocused)
							.onSubmit {
								saveURL()
							}
					} else {
						Text(url)
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
							.foregroundColor(settings.textColorUI)
							.lineLimit(1)
							.truncationMode(.middle)
							.onTapGesture {
								startEditingURL(url)
							}
					}
				}

				Spacer()

				SwiftUI.Button(action: onDelete) {
					Image(systemName: "trash")
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(Color.red.opacity(isHovered ? 0.8 : 0.4))
						.frame(width: 24, height: 24)
				}
				.buttonStyle(PlainButtonStyle())
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.background(settings.searchBarColorUI.opacity(isHovered ? 0.8 : 0.3))
			.cornerRadius(DesignTokens.CornerRadius.md)
			.onHover { hovering in
				isHovered = hovering
			}
			.onAppear {
				loadBrandIcon(url: url)
			}
		)
	}

	private func loadBrandIcon(url: String) {
		if action.icon.hasPrefix("web:") {
			let iconName = String(action.icon.dropFirst(4))
			WebIconDownloader.getIcon(for: iconName, size: NSSize(width: 20, height: 20)) { image in
				DispatchQueue.main.async {
					self.brandIcon = image ?? ActionIconGenerator.loadIcon(
						iconName: self.action.icon,
						title: self.action.name,
						url: url
					)
				}
			}
		} else {
			brandIcon = ActionIconGenerator.loadIcon(iconName: action.icon, title: action.name, url: url)
		}
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
