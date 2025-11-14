import SwiftUI

struct SearchMetrics: View {
	let resultCount: Int
	let searchTimeMs: Double?
	@ObservedObject var settings = AppSettings.shared

	var body: some View {
		HStack(spacing: DesignTokens.Spacing.xs) {
			Text("\(resultCount) result\(resultCount == 1 ? "" : "s")")
				.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
				.foregroundColor(.secondary.opacity(0.5))

			if let searchTimeMs, searchTimeMs > 0 {
				Text("•")
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
					.foregroundColor(.secondary.opacity(0.3))

				Text(String(format: "%.1fms", searchTimeMs))
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
					.foregroundColor(.secondary.opacity(0.5))
			}
		}
		.padding(.horizontal, DesignTokens.Spacing.md)
		.padding(.vertical, DesignTokens.Spacing.sm)
	}
}
