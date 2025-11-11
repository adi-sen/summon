import Foundation

struct ExtensionManifest: Codable {
	let name: String
	let keyword: String
	let script: String
	let description: String?
	let author: String?
	let version: String?
	let icon: String?
}
