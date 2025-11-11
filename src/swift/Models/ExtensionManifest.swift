import Foundation

struct ExtensionManifest: Codable {
	let name: String
	let keyword: String
	let script: String
	let description: String?
	let author: String?
	let version: String?
	let icon: String?
	let env: [String: String]?

	static func load(from extensionDir: String) -> ExtensionManifest? {
		let manifestPath = (extensionDir as NSString).appendingPathComponent("manifest.json")
		guard let data = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
		      let manifest = try? JSONDecoder().decode(ExtensionManifest.self, from: data)
		else { return nil }
		return manifest
	}
}
