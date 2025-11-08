// swift-tools-version: 5.7
import PackageDescription

let package = Package(
	name: "Summon",
	platforms: [.macOS(.v12)],
	products: [
		.executable(name: "Summon", targets: ["Summon"])
	],
	targets: [
		.executableTarget(
			name: "Summon",
			path: "src/swift"
		)
	]
)
