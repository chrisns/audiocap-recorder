// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MultiChannelExample",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "multi-channel", targets: ["MultiChannel"])
    ],
    dependencies: [
        .package(path: "../../..")
    ],
    targets: [
        .executableTarget(
            name: "MultiChannel",
            dependencies: [
                .product(name: "AudioCapCore", package: "AudioCap4")
            ]
        )
    ]
)
