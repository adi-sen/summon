import Foundation

extension Notification.Name {
	static let showClipboard = Notification.Name("showClipboard")
	static let showLauncher = Notification.Name("showLauncher")
	static let showSettings = Notification.Name("showSettings")
	static let openSettings = Notification.Name("com.invoke.openSettings")
	static let switchToExtensionsTab = Notification.Name("switchToExtensionsTab")
	static let shortcutsChanged = Notification.Name("shortcutsChanged")
	static let clearIconCache = Notification.Name("clearIconCache")
	static let windowHidden = Notification.Name("windowHidden")
	static let settingsChanged = Notification.Name("settingsChanged")
	static let trayIconSettingChanged = Notification.Name("trayIconSettingChanged")
	static let dockIconSettingChanged = Notification.Name("dockIconSettingChanged")
	static let trafficLightsSettingChanged = Notification.Name("trafficLightsSettingChanged")
	static let closeAllDropdowns = Notification.Name("closeAllDropdowns")
	static let saveClipboardAsSnippet = Notification.Name("saveClipboardAsSnippet")
	static let refreshAppIndex = Notification.Name("com.invoke.refreshAppIndex")
}
