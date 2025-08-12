# Quick-Start Guide

Get up and running with AudioCap Recorder in just a few minutes. This guide will walk you through capturing audio from running applications on macOS.

## What is AudioCap Recorder?

AudioCap Recorder is a Swift library that captures audio from specific running processes on macOS using ScreenCaptureKit. Unlike traditional microphone recording, it allows you to:

- **Isolate audio streams** from specific applications
- **Record system audio** without capturing background noise
- **Filter by process** using regular expressions
- **Support multiple formats** including CAF, ALAC, AAC, and MP3

## Prerequisites

Before you begin, ensure you have:

- **macOS 14.0** or later
- **Swift 5.9** or later
- **Xcode** (for development)
- **Screen Recording permission** granted to your app

## Installation

### Swift Package Manager

Add AudioCap Recorder to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AudioCap4", from: "1.0.0")
]
```

Or add the library product if developing locally:

```swift
dependencies: [
    .package(path: "../path/to/AudioCap4")
],
targets: [
    .executableTarget(
        name: "YourTarget",
        dependencies: [
            .product(name: "AudioCapCore", package: "AudioCap4")
        ]
    )
]
```

## Your First Recording

Let's create a simple example that captures audio from Safari:

```swift
import Foundation
import Core

func main() async throws {
    print("🎙️ Starting AudioCap Recorder...")
    
    // 1. Check permissions
    let permissionManager = PermissionManager()
    guard permissionManager.checkScreenRecordingPermission() else {
        print("❌ Screen recording permission required")
        print("Go to System Preferences > Privacy & Security > Screen Recording")
        exit(1)
    }
    
    // 2. Set up components
    let processManager = ProcessManager()
    let logger = Logger(verbose: true)
    
    // 3. Find Safari processes
    let processes = try processManager.discoverProcesses(matching: "Safari")
    if processes.isEmpty {
        print("❌ No Safari processes found. Start Safari first!")
        exit(1)
    }
    
    print("🔍 Found \(processes.count) Safari process(es)")
    
    // 4. Initialize audio capturer
    let capturer = AudioCapturer(
        outputDirectoryPath: "recordings",
        logger: logger
    )
    
    // 5. Start recording
    print("⏺️ Recording for 5 seconds...")
    Task {
        try await capturer.startCapture(for: processes)
    }
    
    // 6. Wait and stop
    try await Task.sleep(nanoseconds: 5_000_000_000)
    capturer.stopCapture()
    
    print("✅ Recording complete! Check ./recordings/ for output files")
}

try await main()
```

## Expected Output

When you run the example:

```
🎙️ Starting AudioCap Recorder...
🔍 Found 1 Safari process(es)
⏺️ Recording for 5 seconds...
[INFO] Recording configuration:
[INFO] - Output directory: recordings/
[INFO] - Format: CAF (uncompressed)
[INFO] - Sample rate: 48000 Hz
[INFO] - Channels: 2
✅ Recording complete! Check ./recordings/ for output files
```

The output directory will contain:
```
recordings/
└── Safari_20240101_120000.caf  (524,288 bytes)
```

## Permission Setup

AudioCap Recorder requires **Screen Recording** permission to capture application audio:

1. Open **System Preferences** → **Privacy & Security** → **Screen Recording**
2. Click the **lock** to make changes
3. Add your application or Terminal (if running from command line)
4. **Restart** your application

### Checking Permissions Programmatically

```swift
let permissionManager = PermissionManager()

// Check current permission status
if permissionManager.checkScreenRecordingPermission() {
    print("✅ Screen recording permission granted")
} else {
    print("❌ Permission denied")
    permissionManager.displayPermissionInstructions(for: .screenRecording)
}
```

## Process Discovery

AudioCap Recorder uses regular expressions to find target processes:

```swift
let processManager = ProcessManager()

// Match exact application name
let safariProcesses = try processManager.discoverProcesses(matching: "Safari")

// Match multiple applications
let mediaProcesses = try processManager.discoverProcesses(matching: "Safari|VLC|Music")

// Match any process (use with caution!)
let allProcesses = try processManager.discoverProcesses(matching: ".*")

// Match by bundle identifier pattern
let xcodeProceses = try processManager.discoverProcesses(matching: "com\\.apple\\.dt\\.Xcode")
```

## Audio Formats

AudioCap Recorder supports multiple output formats:

### Uncompressed CAF (Default)
```swift
let capturer = AudioCapturer(
    alacEnabled: false  // Default
)
// Output: .caf files, ~10MB per minute
```

### ALAC Lossless
```swift
let capturer = AudioCapturer(
    alacEnabled: true
)
// Output: .m4a files, ~5MB per minute, perfect quality
```

### Lossy Compression
For lossy formats, use the command-line tool or implement custom compression:

```bash
# AAC compression
audiocap-recorder "Safari" --aac --bitrate 128

# MP3 compression  
audiocap-recorder "Safari" --mp3 --quality high
```

## Configuration Options

### Output Directory
```swift
let capturer = AudioCapturer(
    outputDirectoryPath: "/Users/username/recordings"
)
```

### Multi-Channel Recording
Capture from multiple input devices simultaneously:

```swift
let capturer = AudioCapturer(
    captureInputsEnabled: true  // Enables 8-channel recording
)
```

### Logging
```swift
let logger = Logger(verbose: true)
let capturer = AudioCapturer(logger: logger)
```

## Error Handling

Common errors and solutions:

```swift
do {
    try await capturer.startCapture(for: processes)
} catch AudioRecorderError.permissionDenied(let type) {
    print("Permission denied: \(type)")
    // Handle permission error
} catch AudioRecorderError.processNotFound {
    print("Target process not found")
    // Re-scan for processes
} catch AudioRecorderError.fileSystemError(let message) {
    print("File system error: \(message)")
    // Check disk space and permissions
} catch {
    print("Unexpected error: \(error)")
}
```

## Testing Your Setup

Use the included Quick-Start example to verify everything works:

```bash
# Navigate to the example
cd Examples/QuickStart

# Build and run
swift run quick-start
```

Expected output confirms your setup is working correctly.

## Next Steps

Now that you have AudioCap Recorder running:

1. **Explore Examples**: Check out the Integration Recipes for advanced usage
2. **API Reference**: Browse the complete API documentation
3. **Compression Options**: Learn about [ALAC](Recipes/ALAC.md) and [lossy compression](Recipes/LossyCompression.md)
4. **Multi-Channel Recording**: Set up [8-channel recording](Recipes/MultiChannel.md) for complex scenarios

## Troubleshooting

### "No processes found"
- Ensure the target application is running
- Check your regex pattern with online regex testers
- Try `.*` to see all running processes

### "Permission denied"
- Verify Screen Recording permission is granted
- Restart your application after granting permission
- Check System Preferences → Privacy & Security

### "No audio in output files"
- Ensure the target application is actually playing audio
- Check system volume and application volume
- Verify the application isn't muted

### "Build errors"
- Ensure you're using macOS 14+ and Swift 5.9+
- Clean and rebuild: `swift package clean && swift build`
- Check for any missing dependencies

## Support

If you encounter issues:

1. Check the [troubleshooting section](#troubleshooting) above
2. Review the complete examples for working code
3. Consult the API documentation for detailed reference
4. Open an issue on GitHub with your specific error messages

Happy recording! 🎙️
