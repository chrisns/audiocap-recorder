# Lossy Compression

Lossy compression formats like MP3 provide excellent file size reduction for streaming and distribution use cases.

## Overview

Lossy compression algorithms achieve significant file size reductions by removing audio data that is typically inaudible to human ears. While this results in some quality loss, modern codecs provide excellent perceptual quality at reasonable bitrates.

## Supported Formats

### MP3 Encoding

```swift
import AudiocapRecorder

// Configure MP3 compression
let mp3Config = MP3Configuration(
    bitrate: 320,         // kbps
    quality: .highest,
    channels: 2
)

// Create recorder with MP3 configuration
let recorder = AudioRecorder(
    compressionType: .mp3(mp3Config)
)
```

### Variable Bitrate (VBR)

```swift
// Variable bitrate for optimal size/quality balance
let vbrConfig = MP3Configuration(
    mode: .variableBitrate(
        quality: 0,       // 0 = highest quality VBR
        maxBitrate: 320
    ),
    channels: 2
)
```

## Quality Settings

### Bitrate Recommendations

- **320 kbps**: Near-transparent quality, suitable for critical listening
- **256 kbps**: High quality, good for most music content
- **192 kbps**: Good quality, suitable for speech and podcasts
- **128 kbps**: Acceptable quality, minimal file size

### Quality vs. File Size

| Bitrate | Quality | File Size (1 hour stereo) |
|---------|---------|---------------------------|
| 320 kbps | Excellent | ~144 MB |
| 256 kbps | Very Good | ~115 MB |
| 192 kbps | Good | ~86 MB |
| 128 kbps | Acceptable | ~58 MB |

## Use Cases

- **Streaming**: Real-time audio transmission
- **Podcasts**: Speech content with efficient storage
- **Mobile Apps**: Bandwidth-conscious applications
- **Web Distribution**: Fast loading audio content

## Performance Characteristics

- **Encoding Speed**: Very fast
- **CPU Usage**: Low
- **Compatibility**: Universal support
- **File Size**: 10-15x smaller than uncompressed

## Best Practices

1. **Use VBR** for optimal quality/size balance
2. **256+ kbps** for music content
3. **128-192 kbps** for speech/podcasts
4. **Test different settings** for your specific use case

## See Also

- [Quick Start Guide](../QuickStart.md)
- [ALAC Configuration](ALAC.md)
- [Adaptive Bitrate](AdaptiveBitrate.md)
