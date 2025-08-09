# AudioCap4

Process-filtered system audio recorder for macOS. This command-line tool records system audio and saves it to timestamped `.wav` files, targeting only processes whose names or bundle identifiers match a regular expression. Built with ScreenCaptureKit, AVFoundation, and swift-argument-parser.

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
```

- Press Ctrl+C to stop recording gracefully.
- Default output directory: `~/Documents/audiocap/`
- Output filename format: `YYYY-MM-DD-HH-mm-ss.wav`
- Max recording duration enforced by the app is 12 hours per session.

## Usage

```bash
USAGE: audiocap-recorder <process-regex> [--output-directory <output-directory>] [--verbose] [--capture-inputs]

ARGUMENTS:
  <process-regex>        Regular expression to match process names and paths

OPTIONS:
  -o, --output-directory Output directory for recordings (default: ~/Documents/audiocap)
  -v, --verbose          Enable verbose logging
  -c, --capture-inputs   Capture all audio input devices in addition to process audio (requires Microphone permission)
  -h, --help             Show help information
```

### Examples

```bash
# Record audio from any Chrome-related process
swift run audiocap-recorder "com\.google\.Chrome|Chrome"

# Save to a custom location with verbose logging
swift run audiocap-recorder "Spotify|Music" -o ~/Desktop/captures -v

# Also capture input devices (channels will be added in future versions)
swift run audiocap-recorder "Spotify|Music" -c

# Run the installed/release binary directly
/path/to/audiocap-recorder "Slack|zoom.us"
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
- Output audio is written as PCM `.wav` using the app’s current capture pipeline.
