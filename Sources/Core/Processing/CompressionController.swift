import Foundation
import AVFoundation

final class CompressionController {
    private var engine: CompressionEngineProtocol?
    private(set) var configuration: CompressionConfiguration?

    func initialize(with config: CompressionConfiguration) throws {
        try validateConfiguration(config)
        self.configuration = config
        self.engine = try makeEngine(for: config)
    }

    // New convenience that performs compatibility validation/sanitization before creating an engine
    func initializeWithCompatibility(_ config: CompressionConfiguration) throws {
        let fallback = CompressionFallbackManager()
        // Validate eagerly, but allow sanitization path if invalid
        do {
            try fallback.validateCompatibility(for: config)
            self.configuration = config
        } catch {
            // Try sanitizing and re-validating
            let sanitized = fallback.sanitizeConfiguration(config)
            try fallback.validateCompatibility(for: sanitized)
            self.configuration = sanitized
        }
        if let cfg = self.configuration {
            self.engine = try makeEngine(for: cfg)
        }
    }

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws -> Data? {
        guard let engine = engine else { return nil }
        return try engine.processAudioBuffer(buffer)
    }

    func finalizeCompression() throws -> CompressionStatistics {
        guard let engine = engine else {
            throw CompressionControllerError.engineNotInitialized
        }
        return try engine.finalizeCompression()
    }

    func createOutputFile(at url: URL, format: AVAudioFormat) throws -> AVAudioFile {
        guard let engine = engine else {
            throw CompressionControllerError.engineNotInitialized
        }
        return try engine.createOutputFile(at: url, format: format)
    }

    func validateConfiguration(_ config: CompressionConfiguration) throws {
        // Bitrate validation for lossy formats
        if config.format.isLossy {
            if config.bitrate < 64 || config.bitrate > 320 {
                throw CompressionControllerError.invalidBitrate(config.bitrate)
            }
            let allowedSampleRates: Set<Double> = [22050, 44100, 48000]
            if !allowedSampleRates.contains(config.sampleRate) {
                throw CompressionControllerError.invalidSampleRate(config.sampleRate)
            }
        }

        // MP3 limitations
        if config.format == .mp3 {
            if config.channelCount > 2 {
                throw CompressionControllerError.multiChannelNotSupported(format: .mp3, channels: config.channelCount)
            }
            if config.enableVBR {
                throw CompressionControllerError.vbrNotSupported(format: .mp3)
            }
        }
    }

    private func makeEngine(for config: CompressionConfiguration) throws -> CompressionEngineProtocol {
        switch config.format {
        case .aac:
            return try LossyCompressionEngine(configuration: config)
        case .mp3:
            return try LossyCompressionEngine(configuration: config)
        case .alac:
            return ALACCompressionEngineStub(configuration: config)
        case .uncompressed:
            return PassthroughCompressionEngine()
        }
    }
}

enum CompressionControllerError: LocalizedError, Equatable {
    case engineNotInitialized
    case invalidBitrate(UInt32)
    case invalidSampleRate(Double)
    case vbrNotSupported(format: CompressionConfiguration.CompressionFormat)
    case multiChannelNotSupported(format: CompressionConfiguration.CompressionFormat, channels: UInt32)

    var errorDescription: String? {
        switch self {
        case .engineNotInitialized:
            return "Compression engine has not been initialized"
        case .invalidBitrate(let b):
            return "Invalid bitrate: \(b). Expected 64-320 kbps"
        case .invalidSampleRate(let sr):
            return "Invalid sample rate: \(Int(sr)). Expected 22050, 44100, or 48000 Hz"
        case .vbrNotSupported(let fmt):
            return "VBR is not supported for \(fmt.displayName)"
        case .multiChannelNotSupported(let fmt, let ch):
            return "\(fmt.displayName) does not support \(ch) channels"
        }
    }
}

// MARK: - Engine stubs used for selection/testing
private final class PassthroughCompressionEngine: CompressionEngineProtocol {
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws -> Data? { nil }
    func createOutputFile(at url: URL, format: AVAudioFormat) throws -> AVAudioFile {
        let linearPCMSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: Int(format.channelCount),
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false
        ]
        return try AVAudioFile(forWriting: url, settings: linearPCMSettings, commonFormat: .pcmFormatInt16, interleaved: true)
    }
    func finalizeCompression() throws -> CompressionStatistics {
        return CompressionStatistics(
            sessionId: UUID(),
            format: .uncompressed,
            startTime: Date(),
            endTime: Date(),
            duration: 0,
            originalSize: 0,
            compressedSize: 0,
            compressionRatio: 1.0,
            fileSizeReduction: 0.0,
            bitrate: 0,
            sampleRate: 0,
            channelCount: 0,
            enabledVBR: false,
            encodingTime: 0,
            averageEncodingSpeed: 0,
            cpuUsagePercent: 0,
            memoryUsageMB: 0,
            averageBitrate: nil,
            peakBitrate: nil
        )
    }
    func getCompressionProgress() -> CompressionProgress { .init(bytesProcessed: 0, estimatedTotalBytes: 0, compressionRatio: 1.0, encodingSpeedMBps: 0, timeRemaining: nil) }
}

private final class AACCompressionEngineStub: CompressionEngineProtocol {
    private let configuration: CompressionConfiguration
    init(configuration: CompressionConfiguration) { self.configuration = configuration }
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws -> Data? { return nil }
    func createOutputFile(at url: URL, format: AVAudioFormat) throws -> AVAudioFile { try AVAudioFile(forWriting: url, settings: format.settings) }
    func finalizeCompression() throws -> CompressionStatistics { PassthroughCompressionEngine().tryFinalize(format: .aac, config: configuration) }
    func getCompressionProgress() -> CompressionProgress { PassthroughCompressionEngine().getCompressionProgress() }
}

private final class MP3CompressionEngineStub: CompressionEngineProtocol {
    private let configuration: CompressionConfiguration
    init(configuration: CompressionConfiguration) { self.configuration = configuration }
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws -> Data? { return nil }
    func createOutputFile(at url: URL, format: AVAudioFormat) throws -> AVAudioFile { try AVAudioFile(forWriting: url, settings: format.settings) }
    func finalizeCompression() throws -> CompressionStatistics { PassthroughCompressionEngine().tryFinalize(format: .mp3, config: configuration) }
    func getCompressionProgress() -> CompressionProgress { PassthroughCompressionEngine().getCompressionProgress() }
}

private final class ALACCompressionEngineStub: CompressionEngineProtocol {
    private let configuration: CompressionConfiguration
    init(configuration: CompressionConfiguration) { self.configuration = configuration }
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws -> Data? { return nil }
    func createOutputFile(at url: URL, format: AVAudioFormat) throws -> AVAudioFile { try AVAudioFile(forWriting: url, settings: format.settings) }
    func finalizeCompression() throws -> CompressionStatistics { PassthroughCompressionEngine().tryFinalize(format: .alac, config: configuration) }
    func getCompressionProgress() -> CompressionProgress { PassthroughCompressionEngine().getCompressionProgress() }
}

private extension PassthroughCompressionEngine {
    func tryFinalize(format: CompressionConfiguration.CompressionFormat, config: CompressionConfiguration) -> CompressionStatistics {
        return CompressionStatistics(
            sessionId: UUID(),
            format: format,
            startTime: Date(),
            endTime: Date(),
            duration: 0,
            originalSize: 0,
            compressedSize: 0,
            compressionRatio: format == .uncompressed ? 1.0 : 0.3,
            fileSizeReduction: format == .uncompressed ? 0.0 : 0.7,
            bitrate: config.bitrate,
            sampleRate: config.sampleRate,
            channelCount: config.channelCount,
            enabledVBR: config.enableVBR,
            encodingTime: 0,
            averageEncodingSpeed: 0,
            cpuUsagePercent: 0,
            memoryUsageMB: 0,
            averageBitrate: nil,
            peakBitrate: nil
        )
    }
}
