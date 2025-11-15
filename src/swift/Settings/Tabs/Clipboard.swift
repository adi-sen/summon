import SwiftUI

struct ClipboardTab: View {
    @ObservedObject var settings: AppSettings
    @State private var showingFolderPicker = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                SettingSection(title: "CLIPBOARD HISTORY") {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingRow(label: "Max Items") {
                            RangeSlider(
                                value: Binding(
                                    get: { Double(settings.maxClipboardItems) },
                                    set: { settings.maxClipboardItems = Int($0) }
                                ),
                                range: 5...50,
                                step: 5,
                                valueLabel: { "\(Int($0))" }
                            )
                        }

                        SettingRow(label: "Keep For") {
                            RangeSlider(
                                value: Binding(
                                    get: { Double(settings.clipboardRetentionDays) },
                                    set: { settings.clipboardRetentionDays = Int($0) }
                                ),
                                range: 1...30,
                                step: 1,
                                valueLabel: { "\(Int($0)) day\(Int($0) == 1 ? "" : "s")" }
                            )
                        }
                    }
                }

                SettingSection(title: "IMAGE SAVE") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Save Directory")
                            .font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
                            .foregroundColor(settings.textColorUI)

                        Text("Press ⌘S to save clipboard images to this directory")
                            .font(Font(settings.uiFont.withSize(DesignTokens.Typography.small - 1)))
                            .foregroundColor(settings.secondaryTextColorUI.opacity(0.7))

                        HStack {
                            Text(
                                settings.imageSavePath.isEmpty
                                    ? "Pictures (default)" : settings.imageSavePath
                            )
                            .font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
                            .foregroundColor(
                                settings.imageSavePath.isEmpty
                                    ? settings.secondaryTextColorUI : settings.textColorUI
                            )
                            .lineLimit(1)
                            .truncationMode(.middle)

                            Spacer()

                            Button("Choose Folder", style: .plain) {
                                showingFolderPicker = true
                            }
                        }

                        if !settings.imageSavePath.isEmpty {
                            Button("Reset to Default", style: .plain) {
                                settings.imageSavePath = ""
                                settings.scheduleSave()
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.xxl + DesignTokens.Spacing.xs)
        }
        .background(settings.backgroundColorUI)
        .overlay {
            if showingFolderPicker {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingFolderPicker = false
                    }

                FolderPicker(
                    isPresented: $showingFolderPicker,
                    onSelect: { folder in
                        settings.imageSavePath = folder
                        settings.scheduleSave()
                    }
                )
            }
        }
    }
}
