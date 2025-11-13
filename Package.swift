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
			path: "src/swift",
			swiftSettings: [
				.unsafeFlags(["-import-objc-header", "src/swift/ffi.h"])
			],
			linkerSettings: [
				.unsafeFlags(["-L", "target/debug"]),
				.linkedLibrary("ffi"),
				.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../lib"])
			]
		)
	]
)
