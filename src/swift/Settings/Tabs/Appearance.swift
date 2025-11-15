import SwiftUI

struct AppearanceTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                SettingSection(title: "THEME") {
                    ThemeGrid(settings: settings)
                }

                SettingSection(title: "FONT") {
                    FontPicker(selectedFont: $settings.customFontName, settings: settings)
                }

                SettingSection(title: "UI") {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        toggleRow(
                            label: "Show footer hints",
                            binding: Binding(
                                get: { settings.showFooterHints },
                                set: {
                                    settings.showFooterHints = $0
                                    settings.save()
                                }
                            )
                        )

                        toggleRow(
                            label: "Compact mode",
                            binding: Binding(
                                get: { settings.compactMode },
                                set: {
                                    settings.compactMode = $0
                                    settings.save()
                                }
                            )
                        )

                        toggleRow(
                            label: "Show recent apps on landing",
                            binding: Binding(
                                get: { settings.showRecentAppsOnLanding },
                                set: {
                                    settings.showRecentAppsOnLanding = $0
                                    settings.save()
                                }
                            )
                        )

                        SettingRowWithDescription(
                            label: "Window shadow radius",
                            description: "Adjust the blur radius of the window shadow (0-30)"
                        ) {
                            RangeSlider(
                                value: Binding(
                                    get: { settings.windowShadowRadius },
                                    set: {
                                        settings.windowShadowRadius = $0
                                        settings.scheduleSave()
                                    }
                                ),
                                range: 0...30,
                                step: 1,
                                valueLabel: { String(format: "%.0f", $0) }
                            )
                        }

                        SettingRowWithDescription(
                            label: "Window shadow opacity",
                            description: "Adjust the opacity of the window shadow (0-1)"
                        ) {
                            RangeSlider(
                                value: Binding(
                                    get: { settings.windowShadowOpacity },
                                    set: {
                                        settings.windowShadowOpacity = $0
                                        settings.scheduleSave()
                                    }
                                ),
                                range: 0...1,
                                step: 0.01,
                                valueLabel: { String(format: "%.2f", $0) }
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private func toggleRow(label: String, binding: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .styled(fontSize: DesignTokens.Typography.body, settings: settings)
                .foregroundColor(settings.textColorUI)

            Spacer()

            Switch(isOn: binding)
        }
    }
}
