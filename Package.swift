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
                .unsafeFlags(["-L", "target/release", "-L", "target/debug"]),
                .unsafeFlags(["-Xlinker", "-force_load", "-Xlinker", "target/release/libffi.a"]),
            ]
        )
    ]
)
