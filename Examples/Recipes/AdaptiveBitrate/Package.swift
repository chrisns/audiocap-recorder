// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AdaptiveBitrateExample",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "adaptive-bitrate", targets: ["AdaptiveBitrate"])
    ],
    dependencies: [
        .package(path: "../../..")
    ],
    targets: [
        .executableTarget(
            name: "AdaptiveBitrate",
            dependencies: [
                .product(name: "AudioCapCore", package: "AudioCap4")
            ]
        )
    ]
)
