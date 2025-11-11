import SwiftUI

struct SettingsRowWithDescription<Content: View>: View {
	let label: String
	let description: String?
	let content: Content

	init(label: String, description: String? = nil, @ViewBuilder content: () -> Content) {
		self.label = label
		self.description = description
		self.content = content()
	}

	var body: some View {
		FormField(
			label: label,
			labelStyle: .regular,
			spacing: 8,
			description: description
		) {
			HStack {
				Spacer()
				content
			}
		}
	}
}
