# Technology Stack

## Core Technologies
- **Language**: Swift 5.9+
- **Build System**: Swift Package Manager (SPM)
- **Target Platform**: macOS 12.3+ (optimized for Sequoia 15.6)

## Key Frameworks & Dependencies
- **ScreenCaptureKit**: System audio capture (requires macOS 12.3+)
- **Swift ArgumentParser**: Command-line interface parsing
- **AVFoundation**: Audio processing and format conversion
- **Foundation**: Core system APIs and utilities
- **XCTest**: Testing framework

## System APIs Used
- **NSRunningApplication**: Process discovery
- **NSWorkspace**: Process lifecycle monitoring
- **Core Audio**: WAV format conversion
- **sysctl**: Low-level process enumeration

## Common Commands

### Build & Development
```bash
# Build the project
swift build

# Build for release
swift build -c release

# Run the application
swift run AudioRecorder <regex-pattern>

# Run with custom output directory
swift run AudioRecorder <regex-pattern> --output-directory ~/recordings
```

### Testing
```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose

# Run specific test target
swift test --filter AudioRecorderTests
```

### Project Setup
```bash
# Initialize Swift package (if starting fresh)
swift package init --type executable

# Generate Xcode project
swift package generate-xcodeproj

# Clean build artifacts
swift package clean
```

## Architecture Patterns
- **Protocol-Oriented Design**: All major components implement protocols for testability
- **Delegate Pattern**: Used for audio capture callbacks and process monitoring
- **Command Pattern**: CLI interface using ArgumentParser
- **Observer Pattern**: Process lifecycle monitoring with NSWorkspace

## Performance Considerations
- Circular buffers for audio data to minimize allocations
- Background queues for file I/O operations
- Efficient process polling intervals
- Memory-safe Swift patterns with ARC