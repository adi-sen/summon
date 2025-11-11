import Foundation

struct StoragePathManager {
	static let shared = StoragePathManager()

	let appSupportDir: URL

	init() {
		let fileManager = FileManager.default
		self.appSupportDir =
			fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
			.first?
			.appendingPathComponent("Summon") ?? URL(fileURLWithPath: "/tmp/Summon")

		try? fileManager.createDirectory(
			at: appSupportDir, withIntermediateDirectories: true, attributes: nil
		)
	}

	init(appSupportDir: URL) {
		self.appSupportDir = appSupportDir

		try? FileManager.default.createDirectory(
			at: appSupportDir, withIntermediateDirectories: true, attributes: nil
		)
	}

	var clipboardStoragePath: String {
		appSupportDir.appendingPathComponent("clipboard.rkyv").path
	}

	var snippetStoragePath: String {
		appSupportDir.appendingPathComponent("snippets.rkyv").path
	}

	var imageCacheDir: String {
		let tempDir = NSTemporaryDirectory()
		return (tempDir as NSString).appendingPathComponent("SummonClipboard")
	}

	var appCachePath: String {
		let cacheDir = FileManager.default.urls(
			for: .cachesDirectory, in: .userDomainMask
		).first
		return
			cacheDir?
				.appendingPathComponent("summon-cache-v4.plist").path ?? "/tmp/summon-cache-v4.plist"
	}

	func getActionsPath() -> String {
		appSupportDir.appendingPathComponent("actions.rkyv").path
	}

	func getExtensionsDir() -> String {
		let extensionsDir = appSupportDir.appendingPathComponent("extensions")
		try? FileManager.default.createDirectory(
			at: extensionsDir,
			withIntermediateDirectories: true,
			attributes: nil
		)
		return extensionsDir.path
	}

	func getExtensionPath(forId id: String) -> String {
		let extensionsDir = URL(fileURLWithPath: getExtensionsDir())
		return extensionsDir.appendingPathComponent("\(id).lua").path
	}
}
