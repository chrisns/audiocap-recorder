# Multi-Channel Recording Recipe

Learn how to capture audio from multiple sources simultaneously using 8-channel recording. Perfect for podcasts, interviews, or complex audio setups requiring source isolation.

## Prerequisites

- **macOS 14.0** or later
- **Swift 5.9** or later
- **Screen Recording** and **Microphone** permissions
- Multiple audio applications or input devices

## Why Multi-Channel Recording?

Multi-channel recording provides:

- **Source Isolation**: Each audio source gets its own channel
- **Post-Production Flexibility**: Edit each source independently
- **Professional Quality**: Industry-standard approach for complex audio
- **Future-Proof**: Easy to remix or remaster later

## Channel Layout

AudioCap's 8-channel layout:

| Channels | Source | Description |
|----------|--------|-------------|
| 1-2 | Process Audio | Stereo mix of captured applications |
| 3-8 | Input Devices | Up to 6 microphones/input devices |

## Step-by-Step Implementation

### 1. Enable Required Permissions

Multi-channel recording requires both permissions:

```swift
let permissionManager = PermissionManager()

// Screen recording for process audio
guard permissionManager.checkScreenRecordingPermission() else {
    print("❌ Screen recording permission required")
    exit(1)
}

// Microphone for input devices
guard permissionManager.checkMicrophonePermission() else {
    print("❌ Microphone permission required for input device capture")
    exit(1)
}
```

### 2. Discover Multiple Audio Sources

```swift
let processManager = ProcessManager()

// Find multiple audio applications
let musicProcesses = try? processManager.discoverProcesses(matching: "Music")
let safariProcesses = try? processManager.discoverProcesses(matching: "Safari")
let vlcProcesses = try? processManager.discoverProcesses(matching: "VLC")

var allProcesses: [RecorderProcessInfo] = []
if let music = musicProcesses, !music.isEmpty {
    allProcesses.append(contentsOf: music)
    print("   ✅ Music app found")
}
if let safari = safariProcesses, !safari.isEmpty {
    allProcesses.append(contentsOf: safari)
    print("   ✅ Safari found")
}
```

**Process Discovery Tips:**
- Use multiple `discoverProcesses()` calls for different apps
- Combine results into a single array
- Check each result before adding to avoid empty arrays

### 3. Configure Multi-Channel Capturer

```swift
let capturer = AudioCapturer(
    outputDirectoryPath: "multichannel-recordings",
    captureInputsEnabled: true,   // Enable 8-channel recording
    alacEnabled: true,           // ALAC for better compression
    logger: logger
)
```

**Key Configuration:**
- **captureInputsEnabled: true**: Enables 8-channel mode with input devices
- **alacEnabled: true**: ALAC compression reduces file size significantly
- **outputDirectoryPath**: Custom directory for organized storage

### 4. Start Multi-Channel Recording

```swift
print("⏺️ Starting 8-channel recording for 15 seconds...")
print("📊 Channel layout:")
print("   Ch 1-2: Process audio (stereo mix)")
print("   Ch 3-8: Input devices (up to 6 devices)")

Task {
    do {
        try await capturer.startCapture(for: allProcesses)
    } catch {
        print("❌ Capture error: \(error)")
    }
}

// Record for 15 seconds
try await Task.sleep(nanoseconds: 15_000_000_000)
capturer.stopCapture()
```

## Complete Example Code

```swift
import Foundation
import Core

func main() async throws {
    print("🎛️ Multi-Channel Recording Recipe")
    
    // Check permissions
    let permissionManager = PermissionManager()
    guard permissionManager.checkScreenRecordingPermission() &&
          permissionManager.checkMicrophonePermission() else {
        print("❌ Both screen recording and microphone permissions required")
        exit(1)
    }
    
    let processManager = ProcessManager()
    let logger = Logger(verbose: true)
    
    // Find multiple audio sources
    let musicProcesses = try? processManager.discoverProcesses(matching: "Music")
    let safariProcesses = try? processManager.discoverProcesses(matching: "Safari")
    
    var allProcesses: [RecorderProcessInfo] = []
    [musicProcesses, safariProcesses].compactMap { $0 }.forEach { processes in
        if !processes.isEmpty {
            allProcesses.append(contentsOf: processes)
        }
    }
    
    guard !allProcesses.isEmpty else {
        print("❌ No audio processes found")
        print("Please start Music, Safari, or another audio application")
        exit(1)
    }
    
    // Configure 8-channel recording
    let capturer = AudioCapturer(
        outputDirectoryPath: "multichannel-recordings",
        captureInputsEnabled: true,
        alacEnabled: true,
        logger: logger
    )
    
    print("⏺️ Starting 8-channel recording...")
    
    Task {
        try await capturer.startCapture(for: allProcesses)
    }
    
    try await Task.sleep(nanoseconds: 15_000_000_000)
    capturer.stopCapture()
    
    print("✅ Multi-channel recording complete!")
}

try await main()
```

## Output File Analysis

Multi-channel recordings produce larger files with more data:

```
📁 multichannel-recordings/
   📄 MultiApp_20240101_120000.m4a (12.5 MB)
      🎛️ 8-channel ALAC (lossless)
```

**File Size Comparison (15 seconds):**
- **Stereo CAF**: ~2.5 MB
- **8-channel CAF**: ~10 MB  
- **8-channel ALAC**: ~6 MB (compressed)

## Post-Processing with Audio Tools

### Logic Pro X
1. Import the 8-channel ALAC file
2. Each channel appears as a separate track
3. Process channels independently (EQ, compression, effects)
4. Mix down to stereo or surround format

### Pro Tools
```
1. Create new session with 8 inputs
2. Import 8-channel file
3. Route each channel to separate tracks
4. Apply individual processing chains
```

### Audacity (Free)
1. **File** → **Import** → **Audio**
2. Select 8-channel file
3. Use **Tracks** → **Mix and Render** → **Mix Down to Stereo** for final mix

### Command Line (FFmpeg)

Extract individual channels:
```bash
# Extract channel 1 (left process audio)
ffmpeg -i multichannel.m4a -map 0:0 -ac 1 -filter:a "pan=mono|c0=c0" channel1.wav

# Extract channel 3 (first input device)
ffmpeg -i multichannel.m4a -map 0:0 -ac 1 -filter:a "pan=mono|c0=c2" channel3.wav

# Extract stereo process mix (channels 1-2)
ffmpeg -i multichannel.m4a -map 0:0 -ac 2 -filter:a "pan=stereo|c0=c0|c1=c1" process_stereo.wav
```

Create custom mixes:
```bash
# Mix channels 1, 3, 5 to stereo
ffmpeg -i multichannel.m4a -filter_complex \
  '[0:0]pan=stereo|c0<c0+c2+c4|c1<c1+c2+c4' custom_mix.wav

# Isolate input devices only (channels 3-8)
ffmpeg -i multichannel.m4a -filter_complex \
  '[0:0]pan=stereo|c0<c2+c4+c6|c1<c3+c5+c7' inputs_only.wav
```

## Use Cases

### Podcast Production
- **Host**: Channel 3 (dedicated microphone)
- **Guest**: Channel 4 (separate microphone)  
- **Background Music**: Channels 1-2 (from Music app)
- **Sound Effects**: Channel 5 (from separate app)

### Interview Recording
- **Interviewer**: Channel 3
- **Interviewee**: Channel 4
- **Presentation Audio**: Channels 1-2 (screen share audio)
- **Room Tone**: Channel 5 (ambient microphone)

### Live Streaming
- **Game Audio**: Channels 1-2 (from game process)
- **Streamer Voice**: Channel 3 (primary microphone)
- **Discord/Chat**: Channel 4 (from communication app)
- **Music/Alerts**: Channel 5 (from streaming software)

## Advanced Configurations

### Selective Process Recording
```swift
// Record only specific high-priority processes
let criticalProcesses = try processManager.discoverProcesses(matching: "Zoom|Teams|Discord")
```

### Custom Channel Mapping
```swift
// Future enhancement: specify which input device goes to which channel
// Currently automatically assigns channels 3-8 based on device discovery order
```

### Real-Time Monitoring
```swift
// Add monitoring during recording
let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
    let cpu = cpuMonitor.sampleUsedPercent()
    print("🖥️ CPU: \(String(format: "%.1f", cpu))% - Recording: ✅")
}
```

## Troubleshooting

### "Only 2 channels recorded"
- Ensure `captureInputsEnabled: true`
- Check microphone permission is granted
- Verify input devices are connected and active

### "Large file sizes"
- Use `alacEnabled: true` for compression
- Consider shorter recording durations for testing
- 8-channel files are inherently larger

### "Some channels silent"
- Check input device volumes in System Preferences
- Verify devices aren't muted or disabled
- Test with fewer devices to isolate issues

### "Audio dropouts"
- Monitor CPU usage during recording
- Close unnecessary applications
- Consider using CAF instead of ALAC for lower CPU usage

## Next Steps

- Try [Adaptive Bitrate Recording](AdaptiveBitrate.md) for CPU-aware quality control
- Explore [Mono Recording](MonoRecording.md) for simplified workflows
- Check the [API Documentation](../../build/docs/html/) for advanced options
- Review the [complete example](../../Examples/Recipes/MultiChannel/) source code

Multi-channel recording opens up professional audio production workflows, giving you complete control over each audio source for maximum post-production flexibility.
