# Audiocap Recorder

Process-filtered system audio recorder for macOS. This command-line tool records system audio and saves it to timestamped `.caf` files, targeting only processes whose names or bundle identifiers match a regular expression. Built with ScreenCaptureKit, AVFoundation, and swift-argument-parser.

## Requirements

- macOS 14 (Sonoma) or newer
- Swift 6 toolchain (Xcode 16 or recent Swift toolchain via Homebrew)
- Screen Recording permission for your terminal/app runner

## Permissions

On first run, macOS will require Screen Recording permission for the app that launches the tool (e.g., Terminal, iTerm, or Xcode). Grant access in:

- System Settings → Privacy & Security → Screen Recording → enable your terminal/Xcode

If permission is missing, the tool exits with a clear message.

If using `--capture-inputs`, Microphone permission is also required:

- System Settings → Privacy & Security → Microphone → enable your terminal/Xcode

## Build and Run (from source)

```bash
# In the project root
swift build

# Run with swift run
swift run audiocap-recorder "com.*chrome"

# With options
swift run audiocap-recorder "Spotify|Music" --output-directory ~/Desktop/audiocaps --verbose

# Capture input devices as well (requires Microphone permission)
swift run audiocap-recorder "Spotify|Music" --capture-inputs

# Enable ALAC compression (.m4a output)
swift run audiocap-recorder "Spotify|Music" --alac
```

- Press Ctrl+C to stop recording gracefully.
- Default output directory: `~/Documents/audiocap/`
- Output filename format: `YYYY-MM-DD-HH-mm-ss.caf` (or `.m4a` when `--alac` is used)
- Max recording duration enforced by the app is 12 hours per session.

## Usage

```bash
USAGE: audiocap-recorder <process-regex> [--output-directory <output-directory>] [--verbose] [--capture-inputs] [--alac] [--aac] [--mp3] [--bitrate <kbps>] [--quality <level>] [--vbr] [--sample-rate <hz>]

ARGUMENTS:
  <process-regex>        Regular expression to match process names and paths

OPTIONS:
  -o, --output-directory Output directory for recordings (default: ~/Documents/audiocap)
  -v, --verbose          Enable verbose logging
  -c, --capture-inputs   Capture all audio input devices in addition to process audio (requires Microphone permission)
  -a, --alac             Enable ALAC (Apple Lossless) compression for output files (.m4a)
      --aac              Enable AAC lossy compression for output files (.m4a)
      --mp3              Enable MP3 lossy compression for output files (.mp3)
      --bitrate          Set bitrate for lossy compression in kbps (64–320)
      --quality          Set quality preset: low, medium, high, maximum
      --vbr              Enable Variable Bitrate (VBR) (AAC only)
      --sample-rate      Set sample rate for lossy compression (22050, 44100, 48000)
  -h, --help             Show help information
```

### Lossy Compression

- AAC (`--aac`): High quality at a given bitrate; recommended for most use cases
- MP3 (`--mp3`): Maximum compatibility across players; stereo-only recommended
- Bitrate (`--bitrate`): 64–320 kbps. Defaults to 128 kbps when unspecified
- Quality (`--quality`): maps to typical bitrates (low=64, medium=128, high=192, maximum=256)
- VBR (`--vbr`): AAC-only variable bitrate for improved quality-to-size
- Sample rate (`--sample-rate`): 22050/44100/48000 Hz; defaults to input rate if unset. High-quality SRC is used when conversion is needed

Examples:

```bash
# AAC lossy, default 128 kbps
swift run audiocap-recorder "(?i)chrome" --aac

# AAC VBR at high quality
swift run audiocap-recorder "Spotify|Music" --aac --vbr --quality high

# MP3 lossy at 192 kbps (stereo)
swift run audiocap-recorder "(?i)zoom" --mp3 --bitrate 192

# Lower bitrate for long-form speech
swift run audiocap-recorder "(?i)podcast" --aac --bitrate 96 --sample-rate 44100
```

#### Adaptive bitrate and auto-selection

- The encoder monitors content complexity and may report suggested bitrates during processing (visible in verbose progress logs). Actual encoder bitrate remains fixed for the session to ensure stable encoding; suggestions are advisory.
- A `CompressionAdvisor` is available for estimating sizes and recommending AAC vs MP3 and bitrates based on content type and duration. See `CompressionAdvisorTests` for reference usage.

#### Session metadata and compression statistics

- Alongside audio and `-compression.json` statistics, the tool can emit a `-session.json` sidecar with basic session metadata when invoked programmatically via `FileController.writeSessionMetadata`.

#### Migration and chaining tools (advanced)

- `CompressionMigration` can transcode between formats. A `dryRun` mode is provided for safe usage in tests or previews.
- `CompressionChaining` orchestrates multi-step conversions (e.g., AAC → MP3). Use `dryRun` in headless environments.

### Format Guidance

- Speech/talk: AAC 64–128 kbps, `--bitrate 96` is a good starting point
- Music: AAC 160–256 kbps, or MP3 192 kbps for broad compatibility
- Long-form recordings (hours): consider 96–128 kbps to reduce disk usage
- Multi-channel + lossy: AAC supports up to 8 channels; MP3 is best kept stereo

### Examples

```bash
# Record audio from any Chrome-related process
swift run audiocap-recorder "com\.google\.Chrome|Chrome"

# Save to a custom location with verbose logging
swift run audiocap-recorder "Spotify|Music" -o ~/Desktop/captures -v

# Also capture input devices (channels combined into multi-channel file)
swift run audiocap-recorder "Spotify|Music" -c

# Use ALAC compression (.m4a output)
swift run audiocap-recorder "Spotify|Music" --alac

# Use AAC lossy at 192 kbps
swift run audiocap-recorder "(?i)teams" --aac --bitrate 192
```

### Regex quick guide

Matching is performed as a substring search across process name, bundle identifier, and executable path. To make your pattern case-insensitive, prefix it with `(?i)`. You usually do not need `.*` because the matcher finds occurrences anywhere within the string.

Examples:

```bash
# Case-insensitive match for Chrome
swift run audiocap-recorder "(?i)chrome"

# Case-insensitive match for Zoom
swift run audiocap-recorder "(?i)zoom"

# Case-insensitive match for Slack
swift run audiocap-recorder "(?i)slack"

# Case-insensitive match for Microsoft Teams
swift run audiocap-recorder "(?i)teams"

# Case-insensitive match for any of Chrome, Zoom, Slack, or Teams
swift run audiocap-recorder "(?i)chrome|zoom|slack|teams"
```

Notes:
- Quotes are recommended to keep the shell from interpreting special characters.
- If you want to target an exact bundle identifier instead, you can match it explicitly, e.g. "(?i)com\.google\.Chrome".

## Multi-channel Recording (inputs + process audio)

When `--capture-inputs` is provided, Audiocap Recorder captures available audio input devices along with process audio and writes an 8-channel output at 48 kHz:

- CAF mode (default): `.caf`, Float32 non-interleaved
- ALAC mode (`--alac`): `.m4a`, Apple Lossless (lossless compression)

Channel mapping:
- Channels 1–2: Process audio (stereo)
- Channels 3–8: Input devices (up to 6 devices, one per channel)
- Unused channels are silent (zero-filled)

A channel mapping JSON is written alongside the audio file to document device-to-channel assignments and any device hot-swaps during the session.

### Channel mapping JSON

- Filename: `<timestamp>-channels.json` (e.g., `2025-01-01-12-00-00-channels.json`)
- Contents include a session identifier, device events, and the channel-to-device map. Example structure:

```json
{
  "sessionId": "...",
  "channels": {
    "1": "process",
    "2": "process",
    "3": "Built-in Microphone",
    "4": "USB Mic"
  },
  "events": [
    { "timestamp": "...", "event": "connected", "device": "USB Mic", "channel": 4 },
    { "timestamp": "...", "event": "disconnected", "device": "USB Mic", "channel": 4 }
  ]
}
```

### Device hot-swapping

- Connecting a new input device assigns it to the next available channel (3–8)
- Disconnecting a device marks its channel silent while preserving other channels
- Reconnecting attempts to restore the previous channel assignment when available

## ALAC vs. Uncompressed

- `--alac` produces `.m4a` files using Apple Lossless (bit-perfect) compression
- Typical size reduction: 40–60% vs. uncompressed CAF, content-dependent
- If ALAC encoding fails, the recorder falls back to uncompressed CAF and continues recording

## Troubleshooting

- No audio captured:
  - Verify Screen Recording permission is enabled for your terminal/Xcode
  - Try running with a simpler regex (e.g., "(?i)chrome") and confirm target process is active
- No input device audio with `--capture-inputs`:
  - Ensure Microphone permission is granted for your terminal/Xcode
  - Confirm at least one input device is available in System Settings → Sound → Input
- Headless or remote environments:
  - Integration tests may skip or be limited without a main display or permissions
- Bluetooth or USB devices:
  - Some devices introduce latency or sample-rate changes; reconnection can alter timing
- MP3 notes:
  - MP3 writing may not be available on all systems; the tool will report if unsupported
  - MP3 is best used in stereo; multi-channel lossy is recommended with AAC

## Run Tests

```bash
swift test
# or filter specific tests
swift test --filter CLITests
```

## Build a Release Binary

```bash
# Build optimized binary
swift build -c release

# Binary path (Apple Silicon default)
./.build/release/audiocap-recorder

# Optionally install it onto your PATH
install -m 0755 ./.build/release/audiocap-recorder /usr/local/bin/audiocap-recorder
```

If you prefer a custom destination directory:

```bash
mkdir -p ~/bin
cp ./.build/release/audiocap-recorder ~/bin/
```

## Notes

- Process matching uses a regular expression against discovered process names and paths. Start simple (e.g., "Chrome") and refine as needed (e.g., "com\\.google\\.Chrome").
- On first use, confirm Screen Recording permission or re-run after granting.
- With `--capture-inputs`, confirm Microphone permission and available input devices.
- Output audio is written as PCM `.caf` by default, or `.m4a` when `--alac` is used.
