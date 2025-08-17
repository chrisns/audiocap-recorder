# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AudioCap Recorder is a macOS command-line tool and Swift library for recording system audio from specific applications. It's built with Swift 6, using ScreenCaptureKit and AVFoundation, targeting macOS 14+.

## Essential Commands

### Building
```bash
# Debug build
swift build

# Release build  
swift build -c release

# Build with version info (used in CI)
AUDIOCAP_VERSION=1.0.0 AUDIOCAP_GIT_COMMIT=$(git rev-parse HEAD) AUDIOCAP_BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") swift build
```

### Testing
```bash
# Run all tests
swift test

# Run specific test filter
swift test --filter CLITests

# Run tests with coverage
swift test --enable-code-coverage
```

### Running the CLI
```bash
# Run from source
swift run audiocap-recorder "(?i)chrome"

# Run release binary
.build/release/audiocap-recorder "(?i)chrome" --output-directory ~/Desktop/captures --verbose
```

### Documentation
```bash
# Generate DocC documentation
swift run docgen

# Build documentation site (requires Node.js)
cd docs-site && npm install && npm run build

# Index documentation for search
cd Tools/DocsIndexer && npm install && npm run build-index
```

## Architecture Overview

### Core Components (`Sources/Core/`)

**AudioCapturer** (`Capture/AudioCapturer.swift`): Main capture orchestrator using ScreenCaptureKit. Manages SCStreamConfiguration, handles multi-channel audio routing, and coordinates with AudioProcessor for file writing.

**ProcessManager** (`Process/ProcessManager.swift`): Discovers and filters running processes using regex patterns. Interfaces with SCShareableContent to find capturable applications.

**AudioProcessor** (`Processing/AudioProcessor.swift`): Handles audio format conversion, compression, and file writing. Manages CAF/ALAC/AAC/MP3 encoding through AVAudioFile and custom encoders.

**InputDeviceManager** (`InputDevices/InputDeviceManager.swift`): Manages audio input devices for multi-channel recording. Handles device hot-swapping and channel assignment (channels 3-8).

**FileController** (`Files/FileController.swift`): Manages output file creation, naming, and metadata. Writes channel mapping JSON and compression statistics alongside audio files.

### Compression Pipeline (`Sources/Core/Processing/`)

The compression system uses a modular architecture with fallback mechanisms:
- **CompressionController**: Main coordinator for compression operations
- **AACEncoder/MP3Encoder**: Lossy compression implementations using AVAudioConverter
- **ALACConfiguration**: Apple Lossless compression settings
- **CompressionAdvisor**: Recommends optimal compression settings based on content
- **AdaptiveBitrateController**: Monitors encoding complexity and suggests bitrate adjustments

### CLI Interface (`Sources/CLI/`)

Uses swift-argument-parser for command-line parsing. Main entry point in `main.swift`, with argument handling in `AudioRecorderCLI.swift`.

## Key Design Patterns

1. **Protocol-Oriented Design**: Core components define protocols (`Protocols/`) for testability
2. **Async/Await**: Modern Swift concurrency throughout capture and processing
3. **Ring Buffer**: Efficient audio buffering to prevent data loss during writes
4. **Error Propagation**: Comprehensive error types in `Errors/` with user-friendly presentation

## Testing Strategy

- **Unit Tests** (`Tests/AudiocapRecorderTests/`): Cover individual components with mocks
- **Integration Tests** (`Tests/Integration/`): Test full recording workflows
- **Compression Tests**: Extensive coverage of all compression formats and edge cases
- **Mock Infrastructure** (`Tests/Mocks/`): Reusable test doubles for key components

## CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/ci.yml`):
1. **Version Generation**: Semantic versioning from commit messages
2. **Build & Test**: macOS runner with Swift 6, code coverage reporting
3. **Release Pipeline**: Creates GitHub releases with binaries on main branch
4. **Documentation**: Builds and deploys to GitHub Pages

## Development Notes

- **Permissions Required**: Screen Recording permission for process audio, Microphone permission for input devices
- **Multi-Channel Output**: 8-channel files with channels 1-2 for process audio, 3-8 for inputs
- **Compression Fallback**: Falls back to uncompressed CAF if compression fails
- **Signal Handling**: Graceful shutdown on Ctrl+C with proper file finalization

## Steering Documents

Additional guidance documents are available to help AI assistants understand the project:

- **[Product Steering](.claude/steering/product.md)**: Product purpose, features, user value, and business logic rules
- **[Technical Steering](.claude/steering/tech.md)**: Tech stack, build system, dependencies, and coding conventions
- **[Structure Steering](.claude/steering/structure.md)**: Directory organization, file naming patterns, and component architecture