# Product Overview

## Audio Process Recorder

A command-line macOS application that captures system audio from specific processes using ScreenCaptureKit. The tool allows users to record audio output from target applications identified by regular expression matching, filtering out unrelated system sounds.

### Key Features
- Process-specific audio recording using regex pattern matching
- ScreenCaptureKit integration for system audio capture
- Automatic timestamped CAF file output (optionally ALAC-compressed .m4a via --alac)
- Real-time recording feedback and duration limits
- Graceful shutdown and permission handling
- Optional ALAC (Apple Lossless) compression for smaller files

### Target Platform
- macOS Sequoia 15.6+ (requires ScreenCaptureKit framework)
- Command-line interface for developer and power user workflows
- Requires Screen Recording permissions for audio capture

### Use Cases
- Recording audio from specific applications during development/testing
- Capturing audio output from processes without manual identification
- Automated audio logging for system monitoring
- Content creation workflows requiring isolated application audio