// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BossHelperMac",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "BossHelperMac", targets: ["BossHelperMac"])
    ],
    targets: [
        .executableTarget(
            name: "BossHelperMac",
            path: "Sources/BossHelperMac"
        ),
        .testTarget(
            name: "BossHelperMacTests",
            dependencies: ["BossHelperMac"],
            path: "Tests/BossHelperMacTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
