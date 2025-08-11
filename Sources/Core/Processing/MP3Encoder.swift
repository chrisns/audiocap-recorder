import Foundation
import AVFoundation

final class MP3Encoder: AudioEncoderProtocol, @unchecked Sendable {
    private var audioFile: AVAudioFile?
    private var configuration: LossyCompressionConfiguration?
    private var converter: AVAudioConverter?
    private var startDate: Date?

    internal private(set) var lastSettings: [String: Any] = [:]

    func initialize(configuration: LossyCompressionConfiguration) throws {
        guard configuration.format == .mp3 else {
            throw AudioRecorderError.compressionConfigurationInvalid("MP3Encoder requires MP3 format")
        }
        guard configuration.channelCount >= 1 && configuration.channelCount <= 2 else {
            throw AudioRecorderError.compressionConfigurationInvalid("MP3 supports mono or stereo only")
        }
        if configuration.enableVBR {
            throw AudioRecorderError.compressionConfigurationInvalid("MP3 VBR is not supported")
        }
        self.configuration = configuration
    }

    func createAudioFile(at url: URL, format: AVAudioFormat) throws -> AVAudioFile {
        guard let cfg = configuration else { throw AudioRecorderError.compressionConfigurationInvalid("Encoder not initialized") }
        let settings = createMP3Settings(bitrate: cfg.bitrate, sampleRate: cfg.sampleRate, channelCount: cfg.channelCount)
        lastSettings = settings
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings)
            self.audioFile = file
            self.startDate = Date()
        } catch {
            throw AudioRecorderError.compressionNotSupported("MP3 writing not supported: \(error.localizedDescription)")
        }
        // Prepare converter when needed
        if format.sampleRate != cfg.sampleRate || format.channelCount != AVAudioChannelCount(cfg.channelCount) {
            let dstFormat = AVAudioFormat(standardFormatWithSampleRate: cfg.sampleRate, channels: AVAudioChannelCount(cfg.channelCount))!
            let conv = AVAudioConverter(from: format, to: dstFormat)
            conv?.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering
            self.converter = conv
        } else {
            self.converter = nil
        }
        return self.audioFile!
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
        return Data()
    }

    func finalize() throws -> CompressionStatistics {
        guard let cfg = configuration else { throw AudioRecorderError.compressionConfigurationInvalid("Missing config") }
        let end = Date()
        let start = startDate ?? end
        let duration = end.timeIntervalSince(start)
        let url = audioFile?.url
        let compressedSize = (try? url?.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
        return CompressionStatistics(
            sessionId: UUID(),
            format: .mp3,
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
            averageBitrate: nil,
            peakBitrate: nil
        )
    }

    func getEstimatedFileSize(for duration: TimeInterval) -> Int64 {
        guard let cfg = configuration else { return 0 }
        let bitsPerSecond = Int64(cfg.bitrate) * 1000
        let bytesPerSecond = bitsPerSecond / 8
        return Int64(duration) * bytesPerSecond
    }

    func getCompressionRatio() -> Double { 0.0 }

    func supportsMultiChannel() -> Bool { false }

    func getMaximumChannelCount() -> UInt32 { 2 }

    // MARK: - Settings
    func createMP3Settings(bitrate: UInt32, sampleRate: Double, channelCount: UInt32) -> [String: Any] {
        let channels = min(channelCount, 2)
        return [
            AVFormatIDKey: kAudioFormatMPEGLayer3,
            AVNumberOfChannelsKey: Int(channels),
            AVSampleRateKey: sampleRate,
            AVEncoderBitRateKey: Int(bitrate) * 1000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVSampleRateConverterAudioQualityKey: AVAudioQuality.max.rawValue
        ]
    }
}
