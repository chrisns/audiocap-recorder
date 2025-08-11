@preconcurrency import AVFoundation
import Foundation

final class LossyCompressionEngine: CompressionEngineProtocol {
    private let config: CompressionConfiguration
    private let encoder: AudioEncoderProtocol

    // Progress tracking
    private var bytesProcessed: Int64 = 0            // original PCM bytes processed (approx)
    private var startTime: Date?
    private let cpu = CPUMonitor()
    private var highCpuStart: Date?

    // Background encoding
    private let encodeQueue = DispatchQueue(label: "compression.lossy.encode")
    private let pendingGroup = DispatchGroup()
    private let bufferPool = BufferPool()

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
        highCpuStart = nil
        return try encoder.createAudioFile(at: url, format: format)
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws -> Data? {
        // Approximate incoming PCM size (assume 16-bit equivalent for savings estimation)
        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)
        let originalBytes = Int64(channels * frames * 2)
        bytesProcessed &+= originalBytes

        // Clone buffer to avoid mutation/lifetime issues when encoding asynchronously
        guard let clone = cloneBuffer(buffer) else { return nil }
        let group = pendingGroup
        group.enter()
        let enc = encoder
        encodeQueue.async {
            defer { group.leave() }
            do { _ = try enc.encode(buffer: clone) } catch {}
            self.bufferPool.giveBack(clone)
        }
        return nil
    }

    func finalizeCompression() throws -> CompressionStatistics {
        pendingGroup.wait()
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

        let cpuPercent = cpu.sampleUsedPercent()
        updateDynamicQuality(cpuPercent: cpuPercent, elapsed: elapsed)

        return CompressionProgress(
            bytesProcessed: bytesProcessed,
            estimatedTotalBytes: compressedBytesSoFar,
            compressionRatio: reduction,
            encodingSpeedMBps: speedMBps,
            timeRemaining: nil,
            cpuUsagePercent: cpuPercent,
            elapsedSeconds: elapsed
        )
    }

    private func updateDynamicQuality(cpuPercent: Double, elapsed: TimeInterval) {
        // Simple heuristic: if CPU > 85% for >2s, we would reduce quality. Since encoders are configured at init,
        // we only log intent here; future enhancement can recreate encoder with lower bitrate.
        if cpuPercent > 85 {
            if highCpuStart == nil { highCpuStart = Date() }
        } else {
            highCpuStart = nil
        }
        if let start = highCpuStart, Date().timeIntervalSince(start) > 2.0 {
            // TODO: Recreate encoder with reduced bitrate/config if allowed by pipeline
            // For now, just reset timer to avoid spamming
            highCpuStart = nil
        }
    }

    private func cloneBuffer(_ src: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let fmt = src.format
        let frames = src.frameLength
        guard let dst = bufferPool.rent(format: fmt, frameCapacity: frames) else { return nil }
        dst.frameLength = frames
        if fmt.isInterleaved {
            if let s = src.floatChannelData, let d = dst.floatChannelData {
                let count = Int(frames) * Int(fmt.channelCount)
                d[0].update(from: s[0], count: count)
            }
        } else {
            if let s = src.floatChannelData, let d = dst.floatChannelData {
                let n = Int(frames)
                for ch in 0..<Int(fmt.channelCount) {
                    d[ch].update(from: s[ch], count: n)
                }
            }
        }
        return dst
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
