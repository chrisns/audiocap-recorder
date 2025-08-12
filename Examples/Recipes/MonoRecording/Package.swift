// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MonoRecordingExample",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "mono-recording", targets: ["MonoRecording"])
    ],
    dependencies: [
        .package(path: "../../..")
    ],
    targets: [
        .executableTarget(
            name: "MonoRecording",
            dependencies: [
                .product(name: "AudioCapCore", package: "AudiocapRecorder")
            ]
        )
    ]
)
