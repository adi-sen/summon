import SwiftUI

enum DesignTokens {
	enum Typography {
		static let small: CGFloat = 11
		static let body: CGFloat = 13
		static let title: CGFloat = 14
		static let large: CGFloat = 16
		static let xlarge: CGFloat = 24
		static let icon: CGFloat = 14
		static let iconSmall: CGFloat = 11
		static let iconLarge: CGFloat = 16
	}

	enum Spacing {
		static let xxs: CGFloat = 2
		static let xs: CGFloat = 4
		static let sm: CGFloat = 6
		static let md: CGFloat = 8
		static let lg: CGFloat = 12
		static let xl: CGFloat = 16
		static let xxl: CGFloat = 20
	}

	enum CornerRadius {
		static let sm: CGFloat = 4
		static let md: CGFloat = 6
		static let lg: CGFloat = 8
	}

	enum Layout {
		static let iconSize: CGFloat = 28
		static let buttonHeight: CGFloat = 32
		static let minTouchTarget: CGFloat = 44
	}
}

extension View {
	func styled(fontSize: CGFloat, settings: AppSettings) -> some View {
		font(Font(settings.uiFont.withSize(fontSize)))
	}
}
