# Adaptive Bitrate Encoding

Automatically adjust encoding parameters based on audio content characteristics for optimal quality and file size.

## Overview

Adaptive bitrate encoding analyzes audio content in real-time and dynamically adjusts compression parameters to optimize the balance between file size and perceptual quality. This technique is particularly effective for content with varying complexity, such as music with quiet passages and loud sections.

## How It Works

The adaptive encoder continuously analyzes:
- **Spectral Complexity**: Frequency content density
- **Dynamic Range**: Difference between quiet and loud sections  
- **Temporal Characteristics**: Rate of change in audio content
- **Perceptual Masking**: Psychoacoustic properties

## Configuration

### Basic Adaptive Setup

```swift
import AudiocapRecorder

// Configure adaptive bitrate encoding
let adaptiveConfig = AdaptiveBitrateConfiguration(
    targetBitrate: 256,      // Target average bitrate (kbps)
    minBitrate: 128,         // Minimum bitrate for simple content
    maxBitrate: 320,         // Maximum bitrate for complex content
    analysisWindowMs: 100,   // Analysis window size
    adaptationSpeed: .medium // How quickly to adapt
)

// Create recorder with adaptive configuration
let recorder = AudioRecorder(
    compressionType: .adaptive(adaptiveConfig)
)
```

### Advanced Configuration

```swift
// Fine-tuned adaptive encoding
let advancedConfig = AdaptiveBitrateConfiguration(
    targetBitrate: 256,
    minBitrate: 96,
    maxBitrate: 384,
    analysisWindowMs: 50,        // Faster analysis
    adaptationSpeed: .fast,      // Quick adaptation
    complexityThreshold: 0.7,    // Sensitivity to complexity changes
    enablePsychoacoustic: true   // Use perceptual masking
)
```

## Content-Specific Optimizations

### Music Content

```swift
let musicConfig = AdaptiveBitrateConfiguration(
    targetBitrate: 256,
    minBitrate: 192,        // Higher minimum for music
    maxBitrate: 320,
    analysisWindowMs: 200,   // Longer analysis for musical phrases
    adaptationSpeed: .slow   // Smooth transitions
)
```

### Speech/Podcast Content

```swift
let speechConfig = AdaptiveBitrateConfiguration(
    targetBitrate: 128,
    minBitrate: 64,         // Lower minimum for speech
    maxBitrate: 192,        // Lower maximum sufficient for speech
    analysisWindowMs: 50,    // Quick analysis for speech patterns
    adaptationSpeed: .fast   // Rapid adaptation to speech changes
)
```

## Benefits

### Quality Improvements
- **Optimal Resource Allocation**: Higher bitrates for complex content
- **Perceptual Optimization**: Better subjective quality
- **Artifact Reduction**: Fewer compression artifacts in critical passages

### Efficiency Gains
- **Smaller File Sizes**: Lower bitrates for simple content
- **Bandwidth Optimization**: Ideal for streaming applications
- **Storage Savings**: 20-40% reduction compared to constant bitrate

## Performance Characteristics

| Content Type | Bitrate Range | Quality Improvement | Size Reduction |
|--------------|---------------|-------------------|----------------|
| Classical Music | 192-384 kbps | Excellent | 25-35% |
| Pop/Rock | 160-320 kbps | Very Good | 20-30% |
| Speech/Podcast | 64-192 kbps | Good | 30-40% |
| Mixed Content | 96-320 kbps | Excellent | 25-35% |

## Use Cases

- **Streaming Platforms**: Optimize bandwidth usage
- **Podcast Distribution**: Efficient speech encoding
- **Music Archives**: Balance quality and storage
- **Live Broadcasting**: Real-time adaptive encoding

## Best Practices

1. **Set Appropriate Ranges**: Match min/max to content type
2. **Tune Analysis Window**: Shorter for speech, longer for music
3. **Monitor Performance**: Track bitrate distribution
4. **Test with Real Content**: Validate with actual use cases

## Implementation Example

```swift
// Complete adaptive encoding setup
class AdaptiveRecorder {
    private let recorder: AudioRecorder
    
    init(contentType: ContentType) {
        let config = Self.configurationFor(contentType: contentType)
        self.recorder = AudioRecorder(
            compressionType: .adaptive(config)
        )
    }
    
    static func configurationFor(contentType: ContentType) -> AdaptiveBitrateConfiguration {
        switch contentType {
        case .music:
            return AdaptiveBitrateConfiguration(
                targetBitrate: 256,
                minBitrate: 192,
                maxBitrate: 320,
                analysisWindowMs: 200,
                adaptationSpeed: .slow
            )
        case .speech:
            return AdaptiveBitrateConfiguration(
                targetBitrate: 128,
                minBitrate: 64,
                maxBitrate: 192,
                analysisWindowMs: 50,
                adaptationSpeed: .fast
            )
        case .mixed:
            return AdaptiveBitrateConfiguration(
                targetBitrate: 192,
                minBitrate: 96,
                maxBitrate: 320,
                analysisWindowMs: 100,
                adaptationSpeed: .medium
            )
        }
    }
}
```

## See Also

- [Quick Start Guide](../QuickStart.md)
- [ALAC Configuration](ALAC.md)
- [Lossy Compression](LossyCompression.md)
- [Multi-Channel Recording](MultiChannel.md)
