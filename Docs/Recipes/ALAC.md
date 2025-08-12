# ALAC (Apple Lossless Audio Codec)

ALAC provides high-quality lossless audio compression, ideal for archival and professional use cases.

## Overview

Apple Lossless Audio Codec (ALAC) offers the perfect balance between file size and audio quality, providing bit-perfect reproduction of the original audio while reducing file size by approximately 40-60%.

## Configuration

### Basic ALAC Setup

```swift
import AudiocapRecorder

// Configure ALAC compression
let alacConfig = ALACConfiguration(
    sampleRate: 48000,
    channels: 2,
    bitsPerSample: 24
)

// Create recorder with ALAC configuration
let recorder = AudioRecorder(
    compressionType: .alac(alacConfig)
)
```

### Advanced Configuration

```swift
// High-quality stereo recording
let highQualityConfig = ALACConfiguration(
    sampleRate: 96000,    // High sample rate
    channels: 2,          // Stereo
    bitsPerSample: 24,    // 24-bit depth
    fastMode: false       // Prioritize compression over speed
)
```

## Use Cases

- **Professional Recording**: Studio-quality audio capture
- **Archival**: Long-term storage with perfect quality
- **Music Production**: Maintaining audio fidelity throughout the workflow
- **Broadcasting**: High-quality content distribution

## Performance Characteristics

- **Compression Ratio**: 40-60% size reduction
- **Quality**: Bit-perfect lossless reproduction
- **CPU Usage**: Moderate (higher than lossy formats)
- **Compatibility**: Native macOS and iOS support

## See Also

- [Quick Start Guide](../QuickStart.md)
- [Lossy Compression](LossyCompression.md)
- [Multi-Channel Recording](MultiChannel.md)
