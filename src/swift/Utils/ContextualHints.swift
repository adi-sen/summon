import SwiftUI

struct ContextualHints: View {
	let hints: [HintAction]
	@ObservedObject var settings = AppSettings.shared

	var body: some View {
		HStack(spacing: DesignTokens.Spacing.md) {
			ForEach(hints) { hint in
				HStack(spacing: DesignTokens.Spacing.xs) {
					Text(hint.shortcut)
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(.secondary.opacity(0.6))

					Text(hint.label)
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(.secondary.opacity(0.7))
				}

				if hint.id != hints.last?.id {
					Text("•")
						.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
						.foregroundColor(.secondary.opacity(0.4))
				}
			}
		}
		.padding(.horizontal, DesignTokens.Spacing.md)
		.padding(.vertical, DesignTokens.Spacing.sm)
	}
}

struct HintAction: Identifiable {
	let id = UUID()
	let shortcut: String
	let label: String
}
