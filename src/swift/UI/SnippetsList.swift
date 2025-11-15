import SwiftUI

struct SnippetsList: View {
	@ObservedObject var settings = AppSettings.shared
	@ObservedObject var snippetManager = SnippetManager.shared
	@State private var showingAddSnippet = false
	@State private var initialSnippetContent: String?

	private func hasConflict(_ snippet: Snippet) -> Bool {
		snippetManager.snippets.filter { $0.trigger == snippet.trigger && $0.enabled }.count > 1
	}

	var body: some View {
		ScrollView {
			VStack(spacing: DesignTokens.Spacing.md) {
				ForEach(snippetManager.snippets) { snippet in
					InlineEditableSnippetCard(
						snippet: snippet,
						hasConflict: hasConflict(snippet),
						onUpdate: { updated in
							snippetManager.update(updated)
						},
						onToggle: {
							var updated = snippet
							updated.enabled = !snippet.enabled
							snippetManager.update(updated)
						},
						onDelete: {
							snippetManager.delete(snippet)
						}
					)
				}

				SwiftUI.Button(action: { showingAddSnippet = true }) {
					HStack(spacing: DesignTokens.Spacing.md) {
						Image(systemName: "plus.circle.fill")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.title)))
						Text("Add Snippet")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
					}
					.foregroundColor(settings.accentColorUI)
					.padding(.horizontal, DesignTokens.Spacing.lg)
					.padding(.vertical, DesignTokens.Spacing.md + 2)
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
			}
			.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
		}
		.sheet(isPresented: $showingAddSnippet) {
			AddSnippetView(initialContent: initialSnippetContent)
		}
		.onAppear {
			if let pending = snippetManager.pendingSnippetContent {
				initialSnippetContent = pending
				showingAddSnippet = true
				snippetManager.pendingSnippetContent = nil
			}
		}
		.onChange(of: snippetManager.pendingSnippetContent) { newContent in
			if let newContent {
				initialSnippetContent = newContent
				showingAddSnippet = true
				snippetManager.pendingSnippetContent = nil
			}
		}
	}
}

struct InlineEditableSnippetCard: View {
	let snippet: Snippet
	let hasConflict: Bool
	let onUpdate: (Snippet) -> Void
	let onToggle: () -> Void
	let onDelete: () -> Void
	@ObservedObject var settings = AppSettings.shared
	@State private var isHovered = false
	@State private var editingTrigger = ""
	@State private var editingContent = ""
	@State private var isEditingTrigger = false
	@State private var isEditingContent = false
	@FocusState private var triggerFocused: Bool
	@FocusState private var contentFocused: Bool

	var body: some View {
		HStack(spacing: DesignTokens.Spacing.lg) {
			Switch(isOn: Binding(
				get: { snippet.enabled },
				set: { _ in onToggle() }
			))
			.frame(width: 40)

			Group {
				if isEditingTrigger {
					TextField("Trigger", text: $editingTrigger)
						.textFieldStyle(PlainTextFieldStyle())
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
						.foregroundColor(settings.accentColorUI)
						.focused($triggerFocused)
						.onSubmit {
							saveTrigger()
						}
						.frame(width: 120)
				} else {
					Text(snippet.trigger)
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
						.foregroundColor(settings.accentColorUI)
						.frame(width: 120, alignment: .leading)
						.onTapGesture {
							startEditingTrigger()
						}
				}
			}
			.padding(.horizontal, DesignTokens.Spacing.md + 2)
			.padding(.vertical, DesignTokens.Spacing.sm)
			.background(settings.searchBarColorUI)
			.cornerRadius(DesignTokens.CornerRadius.md)

			Image(systemName: "arrow.right")
				.font(Font(settings.uiFont.withSize(DesignTokens.Spacing.md + 2)))
				.foregroundColor(settings.secondaryTextColorUI)

			if hasConflict, snippet.enabled {
				Image(systemName: "exclamationmark.triangle.fill")
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
					.foregroundColor(Color.orange)
					.help("Duplicate trigger detected")
			}

			Group {
				if isEditingContent {
					TextField("Content", text: $editingContent)
						.textFieldStyle(PlainTextFieldStyle())
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
						.foregroundColor(settings.textColorUI)
						.focused($contentFocused)
						.onSubmit {
							saveContent()
						}
				} else {
					Text(snippet.content)
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
						.foregroundColor(settings.textColorUI)
						.lineLimit(1)
						.onTapGesture {
							startEditingContent()
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
		.padding(.horizontal, DesignTokens.Spacing.lg)
		.padding(.vertical, DesignTokens.Spacing.md)
		.background(settings.searchBarColorUI.opacity(isHovered ? 0.8 : 0.3))
		.cornerRadius(DesignTokens.CornerRadius.md)
		.onHover { hovering in
			isHovered = hovering
		}
	}

	private func startEditingTrigger() {
		editingTrigger = snippet.trigger
		isEditingTrigger = true
		triggerFocused = true
	}

	private func saveTrigger() {
		isEditingTrigger = false
		if !editingTrigger.isEmpty, editingTrigger != snippet.trigger {
			var updated = snippet
			updated.trigger = editingTrigger
			onUpdate(updated)
		}
	}

	private func startEditingContent() {
		editingContent = snippet.content
		isEditingContent = true
		contentFocused = true
	}

	private func saveContent() {
		isEditingContent = false
		if !editingContent.isEmpty, editingContent != snippet.content {
			var updated = snippet
			updated.content = editingContent
			onUpdate(updated)
		}
	}
}
