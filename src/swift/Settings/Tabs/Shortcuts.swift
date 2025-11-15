import SwiftUI

struct ShortcutsTab: View {
	@ObservedObject var settings: AppSettings

	var body: some View {
		ScrollView(showsIndicators: false) {
			VStack(alignment: .leading, spacing: 24) {
				SettingSection(title: "GLOBAL SHORTCUTS") {
					VStack(alignment: .leading, spacing: 12) {
						ShortcutRecorderView(
							label: "Show Launcher", shortcut: $settings.launcherShortcut
						)
						ShortcutRecorderView(
							label: "Clipboard History", shortcut: $settings.clipboardShortcut
						)
					}
				}

				SettingSection(title: "NAVIGATION") {
					VStack(alignment: .leading, spacing: 8) {
						ShortcutInfoRow(
							keys: "↑/↓ or ⌃J/⌃K or ⌃N/⌃P", description: "Navigate results"
						)
						ShortcutInfoRow(keys: "↩ (Enter)", description: "Select item")
						ShortcutInfoRow(keys: "Esc", description: "Hide window")
					}
				}

				SettingSection(title: "QUICK SELECT") {
					VStack(alignment: .leading, spacing: 12) {
						Text("Press modifier + 1-9 to quickly select results")
							.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
							.foregroundColor(settings.textColorUI)

						RadioGroup(
							items: QuickSelectModifier.allCases,
							selection: Binding(
								get: { settings.quickSelectModifier },
								set: { newValue in
									settings.quickSelectModifier = newValue
									settings.scheduleSave()
								}
							),
							label: { $0.name },
							columns: 3,
							settings: settings
						)
					}
				}

				SettingSection(title: "APP ACTIONS") {
					VStack(alignment: .leading, spacing: 12) {
						ShortcutRecorderView(
							label: "Pin/Unpin app", shortcut: $settings.pinAppShortcut
						)
						ShortcutRecorderView(
							label: "Reveal in Finder", shortcut: $settings.revealAppShortcut
						)
						ShortcutRecorderView(
							label: "Copy app path", shortcut: $settings.copyPathShortcut
						)
						ShortcutRecorderView(
							label: "Quit app (if running)", shortcut: $settings.quitAppShortcut
						)
						ShortcutRecorderView(
							label: "Hide app (if running)", shortcut: $settings.hideAppShortcut
						)
					}
				}

				SettingSection(title: "CLIPBOARD ACTIONS") {
					VStack(alignment: .leading, spacing: 12) {
						ShortcutRecorderView(
							label: "Save clipboard item", shortcut: $settings.saveClipboardShortcut
						)
					}
				}
			}
			.padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
		}
		.background(settings.backgroundColorUI)
		.onChange(of: settings.launcherShortcut) { _ in
			settings.scheduleSave()
			NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
		}
		.onChange(of: settings.clipboardShortcut) { _ in
			settings.scheduleSave()
			NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
		}
		.onChange(of: settings.pinAppShortcut) { _ in settings.scheduleSave() }
		.onChange(of: settings.revealAppShortcut) { _ in settings.scheduleSave() }
		.onChange(of: settings.copyPathShortcut) { _ in settings.scheduleSave() }
		.onChange(of: settings.quitAppShortcut) { _ in settings.scheduleSave() }
		.onChange(of: settings.hideAppShortcut) { _ in settings.scheduleSave() }
		.onChange(of: settings.saveClipboardShortcut) { _ in settings.scheduleSave() }
	}
}
