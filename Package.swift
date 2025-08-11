// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudiocapRecorder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "audiocap-recorder", targets: ["AudiocapRecorder"]),
        .executable(name: "SineWavePlayer", targets: ["SineWavePlayer"]) 
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "AudiocapRecorder",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources"
        ),
        .executableTarget(
            name: "SineWavePlayer",
            path: "Tools/SineWavePlayer",
            exclude: ["sine_player"]
        ),
        .testTarget(
            name: "AudiocapRecorderTests",
            dependencies: ["AudiocapRecorder"],
            path: "Tests/AudiocapRecorderTests"
        ),
        .testTarget(
            name: "SineCaptureTests",
            dependencies: ["AudiocapRecorder"],
            path: "Tests/Integration/SineCaptureTests"
        )
    ]
)
