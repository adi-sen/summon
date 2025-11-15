import SwiftUI

struct CommandsTab: View {
	@ObservedObject var settings: AppSettings

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 24) {
				SettingSection(title: "COMMAND SHORTCUTS") {
					VStack(alignment: .leading, spacing: 16) {
						HStack {
							VStack(alignment: .leading, spacing: 4) {
								Text("Enable Commands")
									.font(
										Font(settings.uiFont.withSize(DesignTokens.Typography.body))
									)
									.foregroundColor(settings.textColorUI)

								Text("Enable commands like 'settings', 'quit', 'clipboard'")
									.font(
										Font(
											settings.uiFont.withSize(DesignTokens.Typography.small))
									)
									.foregroundColor(settings.secondaryTextColorUI.opacity(0.7))
							}

							Spacer()

							Switch(
								isOn: Binding(
									get: { settings.enableCommands },
									set: { newValue in
										settings.enableCommands = newValue
										settings.scheduleSave()
									}
								))
						}
					}
				}
			}
			.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
		}
		.background(settings.backgroundColorUI)
	}
}
