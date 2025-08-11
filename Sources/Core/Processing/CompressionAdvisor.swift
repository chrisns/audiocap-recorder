import Foundation

public enum ContentType: String {
    case speech
    case music
    case mixed
    case longForm
}

public struct FormatAdvice: Equatable {
    public let format: CompressionConfiguration.CompressionFormat
    public let recommendedBitrateKbps: UInt32
    public let sampleRate: Double
    public let rationale: String
    public let warnings: [String]
}

public struct FormatComparison: Equatable {
    public struct Entry: Equatable {
        public let format: CompressionConfiguration.CompressionFormat
        public let bitrateKbps: UInt32
        public let estimatedBytes: Int64
    }
    public let durationSeconds: TimeInterval
    public let entries: [Entry]
}

public final class CompressionAdvisor {
    public init() {}

    // Rough size estimate from bitrate (kbps) and duration
    public func estimateSizeBytes(format: CompressionConfiguration.CompressionFormat, bitrateKbps: UInt32, durationSeconds: TimeInterval) -> Int64 {
        let bitsPerSecond = Double(bitrateKbps) * 1000.0
        let bytes = Int64((bitsPerSecond / 8.0) * max(0, durationSeconds))
        // Small container overhead cushion
        return bytes + 1024
    }

    public func compare(durationSeconds: TimeInterval, bitratesKbps: [UInt32], includeMP3: Bool = true) -> FormatComparison {
        var entries: [FormatComparison.Entry] = []
        for b in bitratesKbps.sorted() {
            let aacBytes = estimateSizeBytes(format: .aac, bitrateKbps: b, durationSeconds: durationSeconds)
            entries.append(.init(format: .aac, bitrateKbps: b, estimatedBytes: aacBytes))
            if includeMP3 {
                let mp3Bytes = estimateSizeBytes(format: .mp3, bitrateKbps: b, durationSeconds: durationSeconds)
                entries.append(.init(format: .mp3, bitrateKbps: b, estimatedBytes: mp3Bytes))
            }
        }
        return FormatComparison(durationSeconds: durationSeconds, entries: entries)
    }

    public func recommend(content: ContentType, durationSeconds: TimeInterval, channels: UInt32, needMaxCompatibility: Bool) -> FormatAdvice {
        var warnings: [String] = []
        var format: CompressionConfiguration.CompressionFormat = .aac
        var bitrate: UInt32 = 128
        var sr: Double = 44100
        var rationaleParts: [String] = []

        if needMaxCompatibility {
            if channels > 2 {
                warnings.append("MP3 limited to mono/stereo; multi-channel not supported. Using AAC instead.")
                format = .aac
            } else {
                format = .mp3
                rationaleParts.append("MP3 chosen for maximum playback compatibility")
            }
        }

        switch content {
        case .speech:
            bitrate = 96
            sr = 44100
            rationaleParts.append("Speech optimizes well at 64-128 kbps; 96 kbps selected")
        case .music:
            bitrate = 192
            sr = 48000
            rationaleParts.append("Music benefits from higher bitrates; 192 kbps selected")
        case .mixed:
            bitrate = 128
            sr = 44100
            rationaleParts.append("Mixed content balances quality and size at 128 kbps")
        case .longForm:
            if durationSeconds > 3 * 3600 {
                bitrate = 96
                sr = 44100
                rationaleParts.append("Long-form duration detected; 96 kbps chosen to reduce storage")
            } else {
                bitrate = 128
                sr = 44100
                rationaleParts.append("Moderate length; 128 kbps chosen for balance")
            }
        }

        if format == .mp3 && channels > 2 {
            // Ensure we don't return invalid MP3 recommendation
            format = .aac
        }

        if format == .mp3 {
            rationaleParts.append("Note: MP3 may have larger files at the same bitrate compared to AAC")
        } else {
            rationaleParts.append("AAC typically achieves better quality at the same bitrate vs MP3")
        }

        return FormatAdvice(format: format, recommendedBitrateKbps: bitrate, sampleRate: sr, rationale: rationaleParts.joined(separator: "; "), warnings: warnings)
    }
}
