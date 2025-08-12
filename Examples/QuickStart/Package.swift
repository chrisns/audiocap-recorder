// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickStartExample",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "quick-start", targets: ["QuickStart"])
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "QuickStart",
            dependencies: [
                .product(name: "AudioCapCore", package: "AudiocapRecorder")
            ]
        )
    ]
)
