import SwiftUI

extension Theme {
	var textColorUI: Color {
		Color(red: textColor.0, green: textColor.1, blue: textColor.2)
	}

	var secondaryTextColorUI: Color {
		Color(red: secondaryTextColor.0, green: secondaryTextColor.1, blue: secondaryTextColor.2)
	}

	var accentColorUI: Color {
		Color(red: accentColor.0, green: accentColor.1, blue: accentColor.2)
	}

	var backgroundColorUI: Color {
		Color(red: backgroundColor.0, green: backgroundColor.1, blue: backgroundColor.2)
	}

	var searchBarColorUI: Color {
		Color(red: searchBarColor.0, green: searchBarColor.1, blue: searchBarColor.2)
	}

	var previewColorUI: Color {
		Color(red: previewColor.0, green: previewColor.1, blue: previewColor.2)
	}

	var metadataColorUI: Color {
		Color(red: metadataColor.0, green: metadataColor.1, blue: metadataColor.2)
	}
}

extension AppSettings {
	var textColorUI: Color {
		theme.textColorUI
	}

	var secondaryTextColorUI: Color {
		theme.secondaryTextColorUI
	}

	var accentColorUI: Color {
		theme.accentColorUI
	}

	var backgroundColorUI: Color {
		theme.backgroundColorUI
	}

	var searchBarColorUI: Color {
		theme.searchBarColorUI
	}

	var previewColorUI: Color {
		theme.previewColorUI
	}

	var metadataColorUI: Color {
		theme.metadataColorUI
	}
}
