import SwiftUI

struct GeneralTab: View {
	@ObservedObject var settings: AppSettings

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 24) {
				SettingSection(title: "INTERFACE") {
					VStack(alignment: .leading, spacing: 16) {
						toggleRow(
							label: "Show Tray Icon",
							binding: $settings.showTrayIcon
						)

						toggleRow(
							label: "Show Dock Icon",
							binding: $settings.showDockIcon
						)

						toggleRow(
							label: "Hide Traffic Lights",
							binding: $settings.hideTrafficLights
						)
					}
				}
			}
			.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
		}
		.background(settings.backgroundColorUI)
	}

	private func toggleRow(label: String, binding: Binding<Bool>) -> some View {
		SettingRow(label: label) {
			Switch(isOn: binding)
		}
	}
}
