import AppKit
import SwiftUI

enum UIUtils {
	static func makeColor(_ color: (Double, Double, Double), alpha: Double = 1.0) -> NSColor {
		NSColor(red: color.0, green: color.1, blue: color.2, alpha: alpha)
	}

	static func makeCGColor(_ color: (Double, Double, Double), alpha: Double = 1.0) -> CGColor {
		makeColor(color, alpha: alpha).cgColor
	}
}

extension View {
	@ViewBuilder
	func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
		if condition {
			transform(self)
		} else {
			self
		}
	}
}
