// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudioCap4",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "audiocap-recorder", targets: ["AudioCap4"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "AudioCap4",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "AudioCap4Tests",
            dependencies: ["AudioCap4"]
        )
    ]
)
