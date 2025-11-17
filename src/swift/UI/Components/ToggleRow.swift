import SwiftUI

struct ToggleRow: View {
	let label: String
	let binding: Binding<Bool>
	@EnvironmentObject var settings: AppSettings

	var body: some View {
		SettingRow(label: label) {
			Switch(isOn: binding)
		}
	}
}

extension ToggleRow {
	init(label: String, binding: Binding<Bool>, saveOnChange: Bool = false, settings: AppSettings) {
		self.label = label
		if saveOnChange {
			self.binding = Binding(
				get: { binding.wrappedValue },
				set: {
					binding.wrappedValue = $0
					settings.save()
				}
			)
		} else {
			self.binding = binding
		}
	}
}
