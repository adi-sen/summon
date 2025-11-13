import AppKit
import SwiftUI

struct RangeSlider: View {
	@Binding var value: Double
	let range: ClosedRange<Double>
	let step: Double
	let valueLabel: (Double) -> String
	@ObservedObject var settings = AppSettings.shared
	@State private var textValue: String = ""

	var body: some View {
		HStack(spacing: DesignTokens.Spacing.lg) {
			TextField("", text: $textValue, onCommit: {
				if let newValue = Double(textValue) {
					let clamped = min(max(newValue, range.lowerBound), range.upperBound)
					let stepped = step > 0 ? round(clamped / step) * step : clamped
					value = stepped
				}
				textValue = valueLabel(value)
			})
			.textFieldStyle(PlainTextFieldStyle())
			.font(Font(settings.uiFont.withSize(DesignTokens.Typography.body)))
			.foregroundColor(settings.textColorUI)
			.multilineTextAlignment(.center)
			.frame(width: 50)
			.padding(.horizontal, DesignTokens.Spacing.md + 2)
			.padding(.vertical, DesignTokens.Spacing.sm)
			.background(settings.searchBarColorUI)
			.cornerRadius(DesignTokens.CornerRadius.md)
			.onAppear {
				textValue = valueLabel(value)
			}
			.onChange(of: value) { newValue in
				textValue = valueLabel(newValue)
			}

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
