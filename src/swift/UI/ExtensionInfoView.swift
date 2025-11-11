import SwiftUI

struct ExtensionInfoView: View {
	let action: Action
	let onClose: () -> Void
	@ObservedObject var settings = AppSettings.shared

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Image(systemName: action.icon.isEmpty ? "puzzlepiece.extension" : action.icon)
					.font(.system(size: 32))
					.foregroundColor(settings.accentColorUI)

				VStack(alignment: .leading, spacing: 4) {
					Text(action.name)
						.font(Font(settings.uiFont.withSize(18)))
						.foregroundColor(settings.textColorUI)

					if case let .scriptFilter(keyword, _, _) = action.kind {
						Text("Keyword: \(keyword)")
							.font(Font(settings.uiFont.withSize(12)))
							.foregroundColor(settings.secondaryTextColorUI)
					}
				}

				Spacer()
			}
			.padding(24)
			.background(settings.searchBarColorUI.opacity(0.3))

			Divider().background(Color.white.opacity(0.1))

			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					if case let .scriptFilter(keyword, scriptPath, extensionDir) = action.kind {
						InfoSection(title: "Extension Type", value: "Script Filter (manifest.json)", settings: settings)
						InfoSection(title: "Trigger Keyword", value: keyword, settings: settings)
						InfoSection(title: "Script File", value: scriptPath, settings: settings)
						InfoSection(title: "Extension Directory", value: extensionDir, settings: settings)

						Divider().background(Color.white.opacity(0.1))

						VStack(spacing: 12) {
							Button(action: {
								NSWorkspace.shared.selectFile(
									nil,
									inFileViewerRootedAtPath: extensionDir
								)
							}) {
								HStack(spacing: 8) {
									Image(systemName: "folder")
										.font(.system(size: 14))
									Text("Open in Finder")
										.font(Font(settings.uiFont.withSize(13)))
								}
								.foregroundColor(Color.white)
								.padding(.horizontal, 16)
								.padding(.vertical, 10)
								.frame(maxWidth: .infinity)
								.background(settings.accentColorUI)
								.cornerRadius(6)
							}
							.buttonStyle(PlainButtonStyle())

							Button(action: {
								let manifestPath = (extensionDir as NSString).appendingPathComponent("manifest.json")
								NSWorkspace.shared.open(URL(fileURLWithPath: manifestPath))
							}) {
								HStack(spacing: 8) {
									Image(systemName: "doc.text")
										.font(.system(size: 14))
									Text("Edit manifest.json")
										.font(Font(settings.uiFont.withSize(13)))
								}
								.foregroundColor(settings.textColorUI)
								.padding(.horizontal, 16)
								.padding(.vertical, 10)
								.frame(maxWidth: .infinity)
								.background(settings.searchBarColorUI)
								.cornerRadius(6)
							}
							.buttonStyle(PlainButtonStyle())

							let fullScriptPath = (extensionDir as NSString).appendingPathComponent(scriptPath)
							Button(action: {
								NSWorkspace.shared.open(URL(fileURLWithPath: fullScriptPath))
							}) {
								HStack(spacing: 8) {
									Image(systemName: "terminal")
										.font(.system(size: 14))
									Text("Edit \(scriptPath)")
										.font(Font(settings.uiFont.withSize(13)))
								}
								.foregroundColor(settings.textColorUI)
								.padding(.horizontal, 16)
								.padding(.vertical, 10)
								.frame(maxWidth: .infinity)
								.background(settings.searchBarColorUI)
								.cornerRadius(6)
							}
							.buttonStyle(PlainButtonStyle())
						}
					}
				}
				.padding(24)
			}

			Divider().background(Color.white.opacity(0.1))

			HStack {
				Spacer()
				Button("Close") {
					onClose()
				}
				.buttonStyle(PlainButtonStyle())
				.foregroundColor(settings.textColorUI)
				.padding(.horizontal, 16)
				.padding(.vertical, 8)
				.background(settings.searchBarColorUI)
				.cornerRadius(6)
			}
			.padding(16)
			.background(settings.backgroundColorUI)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(settings.backgroundColorUI)
	}
}

struct InfoSection: View {
	let title: String
	let value: String
	let settings: AppSettings

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(title)
				.font(Font(settings.uiFont.withSize(11)))
				.foregroundColor(settings.secondaryTextColorUI)
				.textCase(.uppercase)

			Text(value)
				.font(Font(settings.uiFont.withSize(13)))
				.foregroundColor(settings.textColorUI)
				.textSelection(.enabled)
				.padding(10)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(settings.searchBarColorUI.opacity(0.5))
				.cornerRadius(4)
		}
	}
}
