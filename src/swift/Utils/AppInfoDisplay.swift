import SwiftUI

struct AppInfoDisplay: View {
	let info: ContentView.AppInfo
	@ObservedObject var settings = AppSettings.shared

	var body: some View {
		HStack(spacing: DesignTokens.Spacing.sm) {
			if let version = info.version {
				Text("v\(version)")
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
					.foregroundColor(.secondary.opacity(0.6))

				Text("•")
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
					.foregroundColor(.secondary.opacity(0.3))
			}

			Text(info.size)
				.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
				.foregroundColor(.secondary.opacity(0.6))

			Text("•")
				.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
				.foregroundColor(.secondary.opacity(0.3))

			Text(info.path)
				.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small)))
				.foregroundColor(.secondary.opacity(0.5))
				.lineLimit(1)
				.truncationMode(.middle)
		}
		.padding(.horizontal, DesignTokens.Spacing.md)
		.padding(.vertical, DesignTokens.Spacing.sm)
	}
}
