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
				IconButton(icon: "xmark.circle.fill") {
					isPresented = false
				}
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

				StyledButton("Cancel", style: .plain) {
					isPresented = false
				}

				StyledButton("Select Current Folder", style: .primary) {
					onSelect(currentPath)
					isPresented = false
				}
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

	var body: some View {
		CompactListItem(
			icon: "folder.fill",
			iconColor: .blue,
			title: name,
			isSelected: isSelected,
			onSelect: onSelect,
			onSecondaryAction: onOpen
		)
	}
}
