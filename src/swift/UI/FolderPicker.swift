import AppKit
import SwiftUI

struct FolderPicker: View {
	@Binding var isPresented: Bool
	let onSelect: (String) -> Void
	@ObservedObject var settings = AppSettings.shared
	@State private var currentPath: String = NSHomeDirectory()
	@State private var selectedFolder: String? = nil

	private func contentsOfDirectory(_ path: String) -> [String] {
		let fileManager = FileManager.default
		guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
			return []
		}

		return contents
			.filter { !$0.hasPrefix(".") }
			.filter { item in
				var isDir: ObjCBool = false
				let fullPath = (path as NSString).appendingPathComponent(item)
				fileManager.fileExists(atPath: fullPath, isDirectory: &isDir)
				return isDir.boolValue
			}
			.sorted()
	}

	private func navigateUp() {
		let parent = (currentPath as NSString).deletingLastPathComponent
		if parent != currentPath, parent != "" {
			currentPath = parent
			selectedFolder = nil
		}
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text("Select Folder")
					.font(Font(settings.uiFont.withSize(16)))
					.foregroundColor(settings.textColorUI)
				Spacer()
				Button(action: { isPresented = false }) {
					Image(systemName: "xmark.circle.fill")
						.font(.system(size: 18))
						.foregroundColor(settings.secondaryTextColorUI)
				}
				.buttonStyle(PlainButtonStyle())
			}
			.padding(16)
			.background(settings.backgroundColorUI)

			Divider()
				.background(Color.white.opacity(0.1))

			HStack(spacing: 8) {
				Button(action: navigateUp) {
					Image(systemName: "chevron.left")
						.font(.system(size: 12))
						.foregroundColor(settings.accentColorUI)
						.frame(width: 24, height: 24)
				}
				.buttonStyle(PlainButtonStyle())
				.disabled(currentPath == "/" || currentPath.isEmpty)

				Text(currentPath)
					.font(Font(settings.uiFont.withSize(12)))
					.foregroundColor(settings.secondaryTextColorUI)
					.lineLimit(1)
					.truncationMode(.middle)

				Spacer()
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 8)
			.background(settings.searchBarColorUI.opacity(0.5))

			ScrollView {
				VStack(alignment: .leading, spacing: 2) {
					ForEach(contentsOfDirectory(currentPath), id: \.self) { folder in
						FolderRow(
							name: folder,
							isSelected: selectedFolder == folder,
							onSelect: {
								selectedFolder = folder
							},
							onOpen: {
								let newPath = (currentPath as NSString).appendingPathComponent(folder)
								currentPath = newPath
								selectedFolder = nil
							}
						)
					}
				}
				.padding(8)
			}

			Divider()
				.background(Color.white.opacity(0.1))

			HStack(spacing: 12) {
				Spacer()

				Button("Cancel") {
					isPresented = false
				}
				.buttonStyle(PlainButtonStyle())
				.foregroundColor(settings.textColorUI)
				.padding(.horizontal, 16)
				.padding(.vertical, 8)
				.background(settings.metadataColorUI)
				.cornerRadius(6)

				Button("Select Current Folder") {
					onSelect(currentPath)
					isPresented = false
				}
				.buttonStyle(PlainButtonStyle())
				.foregroundColor(Color.white)
				.padding(.horizontal, 16)
				.padding(.vertical, 8)
				.background(settings.accentColorUI)
				.cornerRadius(6)
			}
			.padding(16)
			.background(settings.backgroundColorUI)
		}
		.frame(width: 600, height: 500)
		.background(settings.backgroundColorUI)
		.cornerRadius(12)
		.shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
	}
}

struct FolderRow: View {
	let name: String
	let isSelected: Bool
	let onSelect: () -> Void
	let onOpen: () -> Void
	@ObservedObject var settings = AppSettings.shared
	@State private var isHovered = false

	var body: some View {
		Button(action: onSelect) {
			HStack(spacing: 12) {
				Image(systemName: "folder.fill")
					.font(.system(size: 16))
					.foregroundColor(Color.blue.opacity(0.8))

				Text(name)
					.font(Font(settings.uiFont.withSize(13)))
					.foregroundColor(settings.textColorUI)

				Spacer()

				Button(action: onOpen) {
					Image(systemName: "chevron.right")
						.font(.system(size: 12))
						.foregroundColor(settings.secondaryTextColorUI)
				}
				.buttonStyle(PlainButtonStyle())
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.background(
				RoundedRectangle(cornerRadius: 6)
					.fill(isSelected ? settings.accentColorUI.opacity(0.2) : isHovered ? settings
						.searchBarColorUI : Color.clear)
			)
		}
		.buttonStyle(PlainButtonStyle())
		.onHover { hovering in
			isHovered = hovering
		}
	}
}
