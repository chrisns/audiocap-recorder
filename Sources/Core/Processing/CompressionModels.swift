import Foundation
import AVFoundation

/// Primary configuration for compression
public struct CompressionConfiguration: Codable, Equatable {
    var format: CompressionFormat
    var bitrate: UInt32
    var quality: CompressionQuality?
    var enableVBR: Bool
    var sampleRate: Double
    var channelCount: UInt32
    var enableMultiChannel: Bool

    init(
        format: CompressionFormat,
        bitrate: UInt32,
        quality: CompressionQuality?,
        enableVBR: Bool,
        sampleRate: Double,
        channelCount: UInt32,
        enableMultiChannel: Bool
    ) {
        self.format = format
        self.bitrate = bitrate
        self.quality = quality
        self.enableVBR = enableVBR
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.enableMultiChannel = enableMultiChannel
    }

    public enum CompressionFormat: String, Codable, CaseIterable, Sendable {
        case aac
        case mp3
        case alac
        case uncompressed

        var displayName: String {
            switch self {
            case .aac: return "AAC"
            case .mp3: return "MP3"
            case .alac: return "ALAC (Lossless)"
            case .uncompressed: return "Uncompressed"
            }
        }

        var isLossy: Bool { self == .aac || self == .mp3 }

        var fileExtension: String {
            switch self {
            case .aac: return "m4a"
            case .mp3: return "mp3"
            case .alac: return "m4a"
            case .uncompressed: return "caf"
            }
        }
    }

    enum CompressionQuality: String, Codable, CaseIterable, Equatable {
        case low
        case medium
        case high
        case maximum

        var bitrate: UInt32 {
            switch self {
            case .low: return 64
            case .medium: return 128
            case .high: return 192
            case .maximum: return 256
            }
        }

        var description: String {
            switch self {
            case .low: return "Low (64 kbps) - Maximum compression"
            case .medium: return "Medium (128 kbps) - Balanced quality/size"
            case .high: return "High (192 kbps) - High quality"
            case .maximum: return "Maximum (256 kbps) - Near-transparent quality"
            }
        }
    }
}

/// Convenience configuration for lossy encoders
public struct LossyCompressionConfiguration: Equatable {
    let format: LossyFormat
    let bitrate: UInt32
    let enableVBR: Bool
    let sampleRate: Double
    let channelCount: UInt32
    let quality: AVAudioQuality

    enum LossyFormat {
        case aac
        case mp3
    }
}

/// Statistics snapshot recorded at finalize
public struct CompressionStatistics: Codable, Equatable {
    let sessionId: UUID
    let format: CompressionConfiguration.CompressionFormat
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval

    // File size information
    let originalSize: Int64
    let compressedSize: Int64
    let compressionRatio: Double
    let fileSizeReduction: Double

    // Audio quality information
    let bitrate: UInt32
    let sampleRate: Double
    let channelCount: UInt32
    let enabledVBR: Bool

    // Performance metrics
    let encodingTime: TimeInterval
    let averageEncodingSpeed: Double // MB/s
    let cpuUsagePercent: Double
    let memoryUsageMB: Double

    // Quality metrics (for VBR)
    let averageBitrate: UInt32?
    let peakBitrate: UInt32?

    var fileSizeReductionPercentage: Double { fileSizeReduction * 100.0 }
}
