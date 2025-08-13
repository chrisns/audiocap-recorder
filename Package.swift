// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudiocapRecorder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "audiocap-recorder", targets: ["AudiocapRecorder"]),
        .executable(name: "SineWavePlayer", targets: ["SineWavePlayer"]),
        .executable(name: "docgen", targets: ["DocGen"]),
        .library(name: "AudioCapCore", targets: ["Core"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.1"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "Core",
            path: "Sources/Core"
        ),
        .executableTarget(
            name: "AudiocapRecorder",
            dependencies: [
                "Core",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/CLI"
        ),
        .executableTarget(
            name: "SineWavePlayer",
            path: "Tools/SineWavePlayer",
            exclude: ["sine_player"]
        ),
        .testTarget(
            name: "AudiocapRecorderTests",
            dependencies: [
                "AudiocapRecorder",
                "Core"
            ],
            path: "Tests/AudiocapRecorderTests"
        ),
        .testTarget(
            name: "SineCaptureTests",
            dependencies: [
                "AudiocapRecorder",
                "Core"
            ],
            path: "Tests/Integration/SineCaptureTests"
        ),
        .executableTarget(
            name: "DocGen",
            path: "Tools/DocGen"
        ),
        .plugin(
            name: "DocGenPlugin",
            capability: .command(
                intent: .custom(verb: "docgen", description: "Generate DocC API documentation"),
                permissions: [
                    .writeToPackageDirectory(reason: "Emit documentation under build/docs")
                ]
            ),
            path: "Plugins/DocGenPlugin"
        )
    ]
)
