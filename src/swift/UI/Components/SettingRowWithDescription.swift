import SwiftUI

struct SettingRowWithDescription<Content: View>: View {
	let label: String
	let description: String?
	let content: Content
	@ObservedObject var settings = AppSettings.shared

	init(label: String, description: String? = nil, @ViewBuilder content: () -> Content) {
		self.label = label
		self.description = description
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
			HStack {
				Text(label)
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
					.foregroundColor(settings.textColorUI)

				Spacer()

				content
			}

			if let description {
				Text(description)
					.font(Font(settings.uiFont.withSize(DesignTokens.Typography.small - 1)))
					.foregroundColor(settings.secondaryTextColorUI.opacity(0.7))
					.fixedSize(horizontal: false, vertical: true)
			}
		}
		.padding(.vertical, DesignTokens.Spacing.xxs)
	}
}
