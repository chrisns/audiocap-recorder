import Foundation
import AVFoundation

final class LossyCompressionEngine: CompressionEngineProtocol {
    private let config: CompressionConfiguration
    private let encoder: AudioEncoderProtocol

    // Progress tracking
    private var bytesProcessed: Int64 = 0            // original PCM bytes processed (approx)
    private var startTime: Date?

    init(configuration: CompressionConfiguration) throws {
        self.config = configuration
        switch configuration.format {
        case .aac:
            self.encoder = AACEncoder()
        case .mp3:
            self.encoder = MP3Encoder()
        case .alac, .uncompressed:
            throw AudioRecorderError.compressionConfigurationInvalid("LossyCompressionEngine supports AAC/MP3 only")
        }
        let lossyCfg = try Self.makeLossyConfig(from: configuration)
        try self.encoder.initialize(configuration: lossyCfg)
    }

    func createOutputFile(at url: URL, format: AVAudioFormat) throws -> AVAudioFile {
        startTime = Date()
        return try encoder.createAudioFile(at: url, format: format)
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws -> Data? {
        // Approximate incoming PCM size (assume 16-bit equivalent for savings estimation)
        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)
        let originalBytes = Int64(channels * frames * 2)
        bytesProcessed &+= originalBytes
        _ = try encoder.encode(buffer: buffer)
        return nil
    }

    func finalizeCompression() throws -> CompressionStatistics {
        return try encoder.finalize()
    }

    func getCompressionProgress() -> CompressionProgress {
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        let speedMBps = elapsed > 0 ? (Double(bytesProcessed) / 1_000_000.0) / elapsed : 0

        // Estimate compressed bytes so far from bitrate and elapsed time
        let bitsPerSecond = Double(config.bitrate) * 1000.0
        let compressedBytesSoFar = Int64((bitsPerSecond / 8.0) * max(0, elapsed))

        // Compute reduction ratio: 1 - compressed/original
        let reduction = bytesProcessed > 0 ? max(0.0, 1.0 - (Double(compressedBytesSoFar) / Double(bytesProcessed))) : 0.0

        // Estimated total unknown without a target duration; provide current compressed size as estimate
        return CompressionProgress(
            bytesProcessed: bytesProcessed,
            estimatedTotalBytes: compressedBytesSoFar,
            compressionRatio: reduction,
            encodingSpeedMBps: speedMBps,
            timeRemaining: nil
        )
    }

    private static func makeLossyConfig(from config: CompressionConfiguration) throws -> LossyCompressionConfiguration {
        let quality: AVAudioQuality
        if let q = config.quality {
            switch q {
            case .low: quality = .low
            case .medium: quality = .medium
            case .high: quality = .high
            case .maximum: quality = .max
            }
        } else {
            // Infer quality from bitrate
            switch config.bitrate {
            case 0...96: quality = .medium
            case 97...160: quality = .high
            default: quality = .max
            }
        }
        switch config.format {
        case .aac:
            return LossyCompressionConfiguration(
                format: .aac,
                bitrate: config.bitrate,
                enableVBR: config.enableVBR,
                sampleRate: config.sampleRate,
                channelCount: config.channelCount,
                quality: quality
            )
        case .mp3:
            return LossyCompressionConfiguration(
                format: .mp3,
                bitrate: config.bitrate,
                enableVBR: false,
                sampleRate: config.sampleRate,
                channelCount: min(config.channelCount, 2),
                quality: quality
            )
        default:
            throw AudioRecorderError.compressionConfigurationInvalid("Unsupported lossy format: \(config.format)")
        }
    }
}
