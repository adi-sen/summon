import SwiftUI

struct FontOption: Hashable {
	let name: String
	let display: String
}

struct FontPickerMenu: View {
	@Binding var selectedFont: String
	@State private var isExpanded = false

	private let fonts: [FontOption] = [
		FontOption(name: "", display: "System"),
		FontOption(name: "SFMono-Regular", display: "SF Mono"),
		FontOption(name: "Menlo-Regular", display: "Menlo"),
		FontOption(name: "Monaco", display: "Monaco"),
		FontOption(name: "Courier", display: "Courier"),
		FontOption(name: "JetBrains Mono", display: "JetBrains Mono"),
		FontOption(name: "Fira Code", display: "Fira Code"),
		FontOption(name: "Source Code Pro", display: "Source Code Pro"),
		FontOption(name: "IBM Plex Mono", display: "IBM Plex Mono"),
		FontOption(name: "Cascadia Code", display: "Cascadia Code")
	]

	private var selectedFontOption: FontOption {
		fonts.first(where: { $0.name == selectedFont }) ?? fonts[0]
	}

	var body: some View {
		Dropdown(
			items: fonts,
			selection: Binding(
				get: { selectedFontOption },
				set: { newValue in
					selectedFont = newValue.name
				}
			),
			label: { $0.display },
			isExpanded: $isExpanded,
			width: 180
		)
	}
}
