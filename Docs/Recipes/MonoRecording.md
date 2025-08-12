# Mono Recording Recipe

Learn how to capture audio in mono format to reduce file sizes while maintaining audio quality. This recipe is perfect for voice recordings, podcasts, or situations where stereo separation isn't necessary.

## Prerequisites

- **macOS 14.0** or later
- **Swift 5.9** or later  
- **Screen Recording permission** granted
- **Music app** or another audio application running

## Why Mono Recording?

Mono recording offers several advantages:

- **50% smaller file sizes** compared to stereo
- **Ideal for voice content** where stereo separation adds no value
- **Better compression** ratios with lossless formats
- **Simplified post-processing** workflows

## Step-by-Step Implementation

### 1. Set Up Your Project

Create a new Swift package:

```bash
# Create project directory
mkdir MonoRecordingExample && cd MonoRecordingExample

# Initialize Swift package
swift package init --type executable
```

Add AudioCap dependency to `Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MonoRecordingExample",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../path/to/AudioCap4")
    ],
    targets: [
        .executableTarget(
            name: "MonoRecordingExample",
            dependencies: [
                .product(name: "AudioCapCore", package: "AudioCap4")
            ]
        )
    ]
)
```

### 2. Import Required Modules

```swift
import Foundation
import Core
```

**What we're importing:**
- `Foundation`: Basic Swift types and utilities
- `Core`: AudioCap's core recording functionality

### 3. Check Permissions

```swift
// Check permissions first - required for ScreenCaptureKit
let permissionManager = PermissionManager()
guard permissionManager.checkScreenRecordingPermission() else {
    print("❌ Screen recording permission required")
    print("Enable in System Preferences > Privacy & Security > Screen Recording")
    exit(1)
}
```

**Why this matters:**
- AudioCap uses ScreenCaptureKit to capture application audio
- macOS requires explicit permission for screen/audio recording
- The app will fail silently without proper permissions

### 4. Discover Target Processes

```swift
let processManager = ProcessManager()

// Find Music app processes using regex matching
let processes = try processManager.discoverProcesses(matching: "Music")
if processes.isEmpty {
    print("❌ No Music processes found")
    print("Please start the Music app and play some audio")
    exit(1)
}
```

**Process discovery explained:**
- Uses regex pattern matching to find target applications
- `"Music"` matches the macOS Music app executable
- You can use patterns like `"Safari|VLC|Spotify"` for multiple apps
- Returns `[RecorderProcessInfo]` with process details

### 5. Configure Audio Capturer

```swift
let capturer = AudioCapturer(
    outputDirectoryPath: "mono-recordings",  // Where files are saved
    captureInputsEnabled: false,             // Don't capture mic inputs
    alacEnabled: false,                      // Use CAF (could use ALAC)
    logger: logger                           // Optional logging
)
```

**Configuration options:**
- **outputDirectoryPath**: Custom directory for recordings (auto-created)
- **captureInputsEnabled**: `false` = process audio only, `true` = + microphone inputs
- **alacEnabled**: `false` = CAF format, `true` = ALAC compression
- **logger**: Provides verbose output during recording

### 6. Start Recording

```swift
print("⏺️ Recording in mono for 10 seconds...")

// Start capture in background task
Task {
    do {
        try await capturer.startCapture(for: processes)
    } catch {
        print("❌ Capture error: \(error)")
    }
}

// Record for 10 seconds
try await Task.sleep(nanoseconds: 10_000_000_000)

// Stop recording
capturer.stopCapture()
```

**Recording process:**
1. **Background Task**: Recording runs asynchronously to avoid blocking
2. **Duration Control**: Use `Task.sleep()` to control recording length
3. **Error Handling**: Capture and display any recording errors
4. **Clean Stop**: Always call `stopCapture()` to finalize files

## Complete Example Code

Here's the full working example:

```swift
import Foundation
import Core

func main() async throws {
    print("🎵 Mono Recording Recipe")
    print("Captures audio from Music app and outputs mono CAF files")
    
    // 1. Check permissions
    let permissionManager = PermissionManager()
    guard permissionManager.checkScreenRecordingPermission() else {
        print("❌ Screen recording permission required")
        exit(1)
    }
    
    let processManager = ProcessManager()
    let logger = Logger(verbose: true)
    
    // 2. Find Music processes
    let processes = try processManager.discoverProcesses(matching: "Music")
    if processes.isEmpty {
        print("❌ No Music processes found")
        print("Please start the Music app and play some audio")
        exit(1)
    }
    
    print("🔍 Found Music process: \(processes.first!.executableName)")
    
    // 3. Configure for mono recording
    let capturer = AudioCapturer(
        outputDirectoryPath: "mono-recordings",
        captureInputsEnabled: false,
        alacEnabled: false,  // Use CAF for simplicity
        logger: logger
    )
    
    print("⏺️ Recording in mono for 10 seconds...")
    
    // 4. Start recording
    Task {
        do {
            try await capturer.startCapture(for: processes)
        } catch {
            print("❌ Capture error: \(error)")
        }
    }
    
    // 5. Record for 10 seconds
    try await Task.sleep(nanoseconds: 10_000_000_000)
    
    // 6. Stop recording
    capturer.stopCapture()
    
    print("✅ Mono recording complete!")
    print("📁 Output files saved to: mono-recordings/")
}

try await main()
```

## Understanding the Output

After running the example, you'll see output like:

```
🎵 Mono Recording Recipe
Captures audio from Music app and outputs mono CAF files
🔍 Found Music process: Music
⏺️ Recording in mono for 10 seconds...
[INFO] Recording configuration:
[INFO] - Process regex: Music
[INFO] - Output directory: mono-recordings/
[INFO] - Format: CAF (uncompressed)
[INFO] - Sample rate: 48000 Hz
[INFO] - Channels: 2 (downmixed to mono during processing)
✅ Mono recording complete!
📁 Output files saved to: mono-recordings/
   📄 Music_20240101_120000.caf (2.1 MB)
```

## File Format Details

### CAF (Core Audio Format)
- **Container**: Apple's native audio container
- **Compression**: Uncompressed PCM by default
- **Quality**: Lossless, bit-perfect audio
- **Size**: ~10MB per minute for stereo, ~5MB for mono
- **Compatibility**: Best on macOS, convertible for other platforms

### Converting to Other Formats

Use `ffmpeg` to convert CAF files:

```bash
# Convert to MP3 (lossy)
ffmpeg -i Music_recording.caf -acodec mp3 -ab 128k output.mp3

# Convert to WAV (lossless)
ffmpeg -i Music_recording.caf -acodec pcm_s16le output.wav

# Convert to AAC (lossy)
ffmpeg -i Music_recording.caf -acodec aac -ab 128k output.m4a
```

## Mono vs Stereo Technical Details

### How Mono Recording Works

AudioCap captures audio in stereo (2 channels) but processes it as mono:

1. **Capture**: Records stereo audio from the target process
2. **Downmix**: Combines left and right channels: `mono = (left + right) / 2`
3. **Output**: Saves as single-channel audio file

### File Size Comparison

For a 1-minute recording at 48kHz/16-bit:

| Format | Stereo Size | Mono Size | Savings |
|--------|-------------|-----------|---------|
| CAF    | 11.5 MB     | 5.75 MB   | 50%     |
| ALAC   | 6-8 MB      | 3-4 MB    | 50%     |
| AAC    | 1 MB        | 500 KB    | 50%     |

## Advanced Configurations

### Using ALAC Compression

```swift
let capturer = AudioCapturer(
    outputDirectoryPath: "mono-recordings",
    captureInputsEnabled: false,
    alacEnabled: true,  // Enable ALAC compression
    logger: logger
)
// Output: .m4a files with lossless compression
```

### Multiple Process Patterns

```swift
// Record from multiple music applications
let processes = try processManager.discoverProcesses(matching: "Music|Spotify|VLC")

// Record from any application (use carefully!)
let processes = try processManager.discoverProcesses(matching: ".*")
```

### Custom Recording Duration

```swift
// Record for 30 seconds
try await Task.sleep(nanoseconds: 30_000_000_000)

// Record for 5 minutes
try await Task.sleep(nanoseconds: 300_000_000_000)

// Record indefinitely (stop manually)
// Don't call Task.sleep() - control externally
```

## Use Cases

### Podcast Recording
- Record interviews or discussions in mono
- Significantly reduces file sizes for distribution
- Maintains excellent voice quality

### Voice-Over Capture
- Capture application audio for tutorials
- Mono format perfect for narration overlay
- Easy to sync with video in post-production

### Audio Analysis
- Simplified waveform analysis with single channel
- Reduced computational requirements for processing
- Focus on content rather than stereo positioning

## Troubleshooting

### "No processes found"
```bash
# Check if Music is running
ps aux | grep Music

# Try broader pattern
let processes = try processManager.discoverProcesses(matching: ".*")
print("All processes: \(processes.map(\.executableName))")
```

### "Permission denied"
1. Open **System Preferences** → **Privacy & Security** → **Screen Recording**
2. Add your app or Terminal to the allowed list
3. Restart your application

### "No audio in output"
- Ensure the target app is actually playing audio
- Check system volume and app volume
- Verify the app isn't muted

### "Files too large"
Consider using ALAC compression:
```swift
let capturer = AudioCapturer(alacEnabled: true)
```

## Next Steps

- Explore [Multi-Channel Recording](MultiChannel.md) for complex scenarios
- Learn about [Adaptive Bitrate](AdaptiveBitrate.md) for CPU-aware recording
- Check the API Documentation for advanced features
- Review the complete example source code

This recipe provides the foundation for efficient mono audio recording. The 50% file size reduction makes it ideal for voice content while maintaining excellent audio quality.
