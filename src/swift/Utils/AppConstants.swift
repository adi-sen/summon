import Foundation

enum AppConstants {
	enum UI {
		static let appIconSize: CGFloat = 28
		static let smallIconSize: CGFloat = 16
		static let symbolFontSize: CGFloat = 20
		static let smallSymbolFontSize: CGFloat = 13
		static let searchFieldHeight: CGFloat = 36
		static let clipboardPreviewWidth: CGFloat = 375
		static let windowWidth: CGFloat = 600
	}

	enum Clipboard {
		static let pageSize = 9
		static let maxContentSize = 1_048_576 // 1MB
		static let defaultRetentionDays = 30
		static let defaultMaxItems = 100
	}

	enum Search {
		static let defaultMaxResults = 10
		static let minQueryLength = 3
	}

	enum Cache {
		static let iconCacheSize = 100
		static let thumbnailCacheSize = 50
		static let searchResultCacheSize = 100
	}

	enum Performance {
		static let clipboardCheckInterval: TimeInterval = 0.2 // 200ms
		static let searchDebounceDelay: TimeInterval = 0.1
	}
}
