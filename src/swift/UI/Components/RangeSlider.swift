import AppKit
import SwiftUI

struct RangeSlider: View {
	@Binding var value: Double
	let range: ClosedRange<Double>
	let step: Double
	let valueLabel: (Double) -> String
	@ObservedObject var settings = AppSettings.shared

	var body: some View {
		HStack(spacing: 12) {
			Text(valueLabel(value))
				.font(Font(settings.uiFont.withSize(13)))
				.foregroundColor(settings.textColorUI)
				.frame(minWidth: 50, alignment: .trailing)
				.padding(.horizontal, 10)
				.padding(.vertical, 6)
				.background(settings.searchBarColorUI)
				.cornerRadius(6)

			ThemedSliderControl(value: $value, range: range, step: step)
				.frame(width: 120)
		}
	}
}

struct ThemedSliderControl: NSViewRepresentable {
	@Binding var value: Double
	let range: ClosedRange<Double>
	let step: Double
	@ObservedObject var settings = AppSettings.shared

	func makeNSView(context: Context) -> NSSlider {
		let slider = NSSlider()
		slider.minValue = range.lowerBound
		slider.maxValue = range.upperBound
		slider.doubleValue = value
		slider.numberOfTickMarks = 0
		slider.allowsTickMarkValuesOnly = step > 0
		slider.target = context.coordinator
		slider.action = #selector(Coordinator.valueChanged(_:))

		slider.trackFillColor = NSColor(settings.accentColorUI)

		return slider
	}

	func updateNSView(_ slider: NSSlider, context _: Context) {
		slider.doubleValue = value
		slider.trackFillColor = NSColor(settings.accentColorUI)
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	class Coordinator: NSObject {
		var parent: ThemedSliderControl

		init(_ parent: ThemedSliderControl) {
			self.parent = parent
		}

		@objc func valueChanged(_ sender: NSSlider) {
			let newValue: Double = if parent.step > 0 {
				round(sender.doubleValue / parent.step) * parent.step
			} else {
				sender.doubleValue
			}
			parent.value = newValue
		}
	}
}
