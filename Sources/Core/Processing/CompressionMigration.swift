import Foundation
import AVFoundation

public enum CompressionMigrationError: Error {
    case unsupportedFormat
    case ioFailure(String)
}

public final class CompressionMigration {
    public init() {}

    public func transcode(
        inputURL: URL,
        to targetFormat: CompressionConfiguration.CompressionFormat,
        bitrateKbps: UInt32,
        sampleRate: Double,
        channels: UInt32,
        outputURL: URL,
        dryRun: Bool = false
    ) throws -> URL {
        if dryRun {
            // Simulate migration success by touching the output URL
            try Data().write(to: outputURL)
            return outputURL
        }
        let inputFile = try AVAudioFile(forReading: inputURL)
        let inputFormat = inputFile.processingFormat
        let dstFormat: AVAudioFormat
        var settings: [String: Any] = [:]
        switch targetFormat {
        case .aac:
            settings = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: Int(min(channels, 8)),
                AVSampleRateKey: sampleRate,
                AVEncoderBitRateKey: Int(bitrateKbps) * 1000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        case .mp3:
            settings = [
                AVFormatIDKey: kAudioFormatMPEGLayer3,
                AVNumberOfChannelsKey: Int(min(channels, 2)),
                AVSampleRateKey: sampleRate,
                AVEncoderBitRateKey: Int(bitrateKbps) * 1000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
        case .alac:
            settings = [
                AVFormatIDKey: kAudioFormatAppleLossless,
                AVNumberOfChannelsKey: Int(min(channels, 8)),
                AVSampleRateKey: sampleRate
            ]
        case .uncompressed:
            settings = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVNumberOfChannelsKey: Int(channels),
                AVSampleRateKey: sampleRate,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false
            ]
        }
        guard let df = AVAudioFormat(settings: settings) else { throw CompressionMigrationError.unsupportedFormat }
        dstFormat = df

        let outFile = try AVAudioFile(forWriting: outputURL, settings: settings, commonFormat: .pcmFormatInt16, interleaved: true)
        let bufferCapacity: AVAudioFrameCount = 4096
        let converter = AVAudioConverter(from: inputFormat, to: dstFormat)
        while true {
            guard let srcBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: bufferCapacity) else { break }
            try inputFile.read(into: srcBuffer)
            if srcBuffer.frameLength == 0 { break }
            if let conv = converter {
                guard let dstBuffer = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: srcBuffer.frameLength) else { break }
                var err: NSError?
                let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                    outStatus.pointee = .haveData
                    return srcBuffer
                }
                conv.convert(to: dstBuffer, error: &err, withInputFrom: inputBlock)
                if let err = err { throw CompressionMigrationError.ioFailure(err.localizedDescription) }
                try outFile.write(from: dstBuffer)
            } else {
                try outFile.write(from: srcBuffer)
            }
        }
        return outputURL
    }
}
