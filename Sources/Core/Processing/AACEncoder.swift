import Foundation
import AVFoundation

final class AACEncoder: AudioEncoderProtocol {
    private var audioFile: AVAudioFile?
    private var configuration: LossyCompressionConfiguration?
    private var converter: AVAudioConverter?
    private var startDate: Date?

    // Exposed for tests within module
    internal private(set) var lastSettings: [String: Any] = [:]

    func initialize(configuration: LossyCompressionConfiguration) throws {
        guard configuration.format == .aac else {
            throw AudioRecorderError.compressionConfigurationInvalid("AACEncoder requires AAC format")
        }
        guard configuration.channelCount >= 1 && configuration.channelCount <= 8 else {
            throw AudioRecorderError.compressionConfigurationInvalid("AAC supports 1-8 channels")
        }
        self.configuration = configuration
    }

    func createAudioFile(at url: URL, format: AVAudioFormat) throws -> AVAudioFile {
        guard let cfg = configuration else { throw AudioRecorderError.compressionConfigurationInvalid("Encoder not initialized") }
        let settings = createAACSettings(bitrate: cfg.bitrate, sampleRate: cfg.sampleRate, channelCount: cfg.channelCount, enableVBR: cfg.enableVBR)
        lastSettings = settings
        let file = try AVAudioFile(forWriting: url, settings: settings)
        self.audioFile = file
        self.startDate = Date()
        // Prepare converter when needed
        if format.sampleRate != cfg.sampleRate || format.channelCount != AVAudioChannelCount(cfg.channelCount) {
            let dstFormat = AVAudioFormat(standardFormatWithSampleRate: cfg.sampleRate, channels: AVAudioChannelCount(cfg.channelCount))!
            let conv = AVAudioConverter(from: format, to: dstFormat)
            // Prefer mastering SRC for best anti-aliasing quality when available
            // Prefer high-quality sample rate conversion when available via option key
            conv?.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering
            self.converter = conv
        } else {
            self.converter = nil
        }
        return file
    }

    func encode(buffer: AVAudioPCMBuffer) throws -> Data {
        guard let file = audioFile else { throw AudioRecorderError.compressionConfigurationInvalid("Audio file not created") }
        if let converter = converter {
            guard let cfg = configuration else { throw AudioRecorderError.compressionConfigurationInvalid("Missing config") }
            let dstFormat = AVAudioFormat(standardFormatWithSampleRate: cfg.sampleRate, channels: AVAudioChannelCount(cfg.channelCount))!
            let frameCapacity = AVAudioFrameCount(buffer.frameLength)
            guard let dstBuffer = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: frameCapacity) else {
                throw AudioRecorderError.compressionConfigurationInvalid("Failed to allocate conversion buffer")
            }
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            converter.convert(to: dstBuffer, error: &error, withInputFrom: inputBlock)
            if let error = error { throw error }
            try file.write(from: dstBuffer)
        } else {
            try file.write(from: buffer)
        }
        // We return empty Data here; file writing is the primary output path
        return Data()
    }

    func finalize() throws -> CompressionStatistics {
        guard let cfg = configuration else { throw AudioRecorderError.compressionConfigurationInvalid("Missing config") }
        let end = Date()
        let start = startDate ?? end
        let duration = end.timeIntervalSince(start)
        let url = audioFile?.url
        let compressedSize = (try? url?.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0 ?? 0) } ?? 0
        let avgKbps: UInt32 = duration > 0 ? UInt32((Double(compressedSize) * 8.0 / duration) / 1000.0) : cfg.bitrate
        return CompressionStatistics(
            sessionId: UUID(),
            format: .aac,
            startTime: start,
            endTime: end,
            duration: duration,
            originalSize: 0,
            compressedSize: compressedSize,
            compressionRatio: 0,
            fileSizeReduction: 0,
            bitrate: cfg.bitrate,
            sampleRate: cfg.sampleRate,
            channelCount: cfg.channelCount,
            enabledVBR: cfg.enableVBR,
            encodingTime: duration,
            averageEncodingSpeed: duration > 0 ? (Double(compressedSize) / 1_000_000.0) / duration : 0,
            cpuUsagePercent: 0,
            memoryUsageMB: 0,
            averageBitrate: cfg.enableVBR ? avgKbps : nil,
            peakBitrate: cfg.enableVBR ? avgKbps : nil
        )
    }

    func getEstimatedFileSize(for duration: TimeInterval) -> Int64 {
        guard let cfg = configuration else { return 0 }
        let bitsPerSecond = Int64(cfg.bitrate) * 1000
        let bytesPerSecond = bitsPerSecond / 8
        return Int64(duration) * bytesPerSecond
    }

    func getCompressionRatio() -> Double { 0.0 }

    func supportsMultiChannel() -> Bool { true }

    func getMaximumChannelCount() -> UInt32 { 8 }

    // MARK: - Settings
    func createAACSettings(bitrate: UInt32, sampleRate: Double, channelCount: UInt32, enableVBR: Bool) -> [String: Any] {
        var settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: Int(channelCount),
            AVSampleRateKey: sampleRate,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVSampleRateConverterAudioQualityKey: AVAudioQuality.max.rawValue
        ]
        if enableVBR {
            settings[AVEncoderBitRateStrategyKey] = AVAudioBitRateStrategy_Variable
            // For VBR we can hint quality via AVEncoderAudioQualityForVBRKey
            settings[AVEncoderAudioQualityForVBRKey] = avQualityForBitrate(bitrate).rawValue
        } else {
            settings[AVEncoderBitRateStrategyKey] = AVAudioBitRateStrategy_Constant
            settings[AVEncoderBitRateKey] = Int(bitrate) * 1000
        }
        return settings
    }

    private func avQualityForBitrate(_ bitrate: UInt32) -> AVAudioQuality {
        switch bitrate {
        case 0...96: return .medium
        case 97...160: return .high
        default: return .max
        }
    }
}
