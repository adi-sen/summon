import SwiftUI

extension AppSettings {
	private func colorUI(from tuple: (Double, Double, Double)) -> Color {
		Color(red: tuple.0, green: tuple.1, blue: tuple.2)
	}

	var textColorUI: Color {
		colorUI(from: theme.textColor)
	}

	var secondaryTextColorUI: Color {
		colorUI(from: theme.secondaryTextColor)
	}

	var accentColorUI: Color {
		colorUI(from: theme.accentColor)
	}

	var backgroundColorUI: Color {
		colorUI(from: theme.backgroundColor)
	}

	var searchBarColorUI: Color {
		colorUI(from: theme.searchBarColor)
	}

	var previewColorUI: Color {
		colorUI(from: theme.previewColor)
	}

	var metadataColorUI: Color {
		colorUI(from: theme.metadataColor)
	}

	var secondaryTextColorUI40: Color { secondaryTextColorUI.opacity(0.4) }
	var secondaryTextColorUI70: Color { secondaryTextColorUI.opacity(0.7) }
	var secondaryTextColorUI50: Color { secondaryTextColorUI.opacity(0.5) }
	var secondaryTextColorUI60: Color { secondaryTextColorUI.opacity(0.6) }
	var accentColorUI15: Color { accentColorUI.opacity(0.15) }
	var accentColorUI30: Color { accentColorUI.opacity(0.3) }
	var searchBarColorUI30: Color { searchBarColorUI.opacity(0.3) }
	var searchBarColorUI50: Color { searchBarColorUI.opacity(0.5) }
}
