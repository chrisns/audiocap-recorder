# AudioCap Recorder Quick-Start Example

A minimal Swift example demonstrating how to capture audio from running processes using the AudioCap Recorder library.

## Features

- Captures audio from Safari browser processes for 5 seconds
- Demonstrates process discovery and audio capture workflow
- Saves output as CAF files (Apple's Core Audio Format)
- Shows proper permission handling for screen recording

## Requirements

- macOS 14+
- Swift 5.9+
- Screen Recording permission (required for audio capture)
- Safari browser running with audio content

## Building and Running

### From Command Line

```bash
# Navigate to the example directory
cd Examples/QuickStart

# Build the example
swift build

# Run the example (requires Safari to be running with audio)
swift run quick-start
```

### Expected Output

```
🎙️ AudioCap Recorder Quick-Start Example
This example captures audio from Safari browser for 5 seconds
Make sure Safari is running and playing audio...
🔍 Found 1 Safari process(es):
   - Safari (PID: 12345)
⏺️ Starting capture for 5 seconds...
✅ Recording complete!
📁 Check the output directory for recorded files:
   📄 Safari_20240101_120000.caf (524288 bytes)
```

### If Safari is not running:

```
❌ No Safari processes found. Please start Safari and play some audio.
```

### If Screen Recording permission is not granted:

```
❌ Screen recording permission required
Please go to System Preferences > Privacy & Security > Screen Recording
and enable permission for this app
```

## Code Overview

The example demonstrates the core AudioCap Recorder workflow:

1. **Permission Check**: Verify screen recording permission is granted
2. **Process Discovery**: Find running Safari processes using regex matching
3. **Component Initialization**: Create capturer, processor, and file controller
4. **Audio Capture**: Start capture from discovered processes
5. **Output**: Save captured audio to timestamped CAF files

## How It Works

AudioCap Recorder uses macOS's ScreenCaptureKit to capture audio from specific processes. Unlike traditional microphone recording, this allows you to:

- Capture audio only from specific applications
- Record system audio without background noise
- Isolate audio streams by process

## Next Steps

- Try different process patterns (e.g., "Music", "VLC", ".*" for all processes)
- Explore [ALAC compression](../Recipes/ALAC/) for lossless audio
- Check out [multichannel recording](../Recipes/MultiChannel/) for capturing multiple applications
- Read the [API Documentation](../../build/docs/html/) for detailed reference
