import SwiftUI

struct Switch: View {
	@Binding var isOn: Bool
	@ObservedObject var settings = AppSettings.shared

	var body: some View {
		Button(action: { isOn.toggle() }) {
			HStack(spacing: 0) {
				RoundedRectangle(cornerRadius: 4)
					.fill(Color.white)
					.frame(width: 16, height: 16)
					.shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
					.offset(x: isOn ? 10 : -10)
					.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
			}
			.frame(width: 40, height: 20)
			.background(
				RoundedRectangle(cornerRadius: 6)
					.fill(isOn ? settings.accentColorUI : settings.metadataColorUI.opacity(0.5))
			)
		}
		.buttonStyle(PlainButtonStyle())
	}
}
