import SwiftUI

struct SearchMetrics: View {
	let resultCount: Int
	let searchTimeMs: Double?

	var body: some View {
		HStack(spacing: DesignTokens.Spacing.xs) {
			Text("\(resultCount) result\(resultCount == 1 ? "" : "s")")
				.font(.system(size: DesignTokens.Typography.small, design: .monospaced))
				.foregroundColor(.secondary.opacity(0.5))

			if let searchTimeMs, searchTimeMs > 0 {
				Text("•")
					.font(.system(size: DesignTokens.Typography.small))
					.foregroundColor(.secondary.opacity(0.3))

				Text(String(format: "%.1fms", searchTimeMs))
					.font(.system(size: DesignTokens.Typography.small, design: .monospaced))
					.foregroundColor(.secondary.opacity(0.5))
			}
		}
		.padding(.horizontal, DesignTokens.Spacing.md)
		.padding(.vertical, DesignTokens.Spacing.sm)
	}
}
