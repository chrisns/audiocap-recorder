import XCTest
import AVFoundation
 import Core

final class CompressionIntegrationTests: XCTestCase {
    func testAACEstimatedFileSizeRoughlyMatchesBitrate() throws {
        let enc = AACEncoder()
        try enc.initialize(configuration: .init(format: .aac, bitrate: 128, enableVBR: false, sampleRate: 44100, channelCount: 2, quality: .high))
        let seconds: TimeInterval = 10
        let estBytes = enc.getEstimatedFileSize(for: seconds)
        // 128 kbps ~ 16 KB/s => ~160 KB over 10s
        XCTAssertGreaterThan(estBytes, 100 * 1024)
        XCTAssertLessThan(estBytes, 300 * 1024)
    }

    func testLossyProgressIncludesElapsed() throws {
        let cfg = CompressionConfiguration(format: .aac, bitrate: 128, quality: .medium, enableVBR: false, sampleRate: 44100, channelCount: 2, enableMultiChannel: false)
        let engine = try LossyCompressionEngine(configuration: cfg)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        _ = try engine.createOutputFile(at: url, format: fmt)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 1024)!
        buf.frameLength = 1024
        _ = try engine.processAudioBuffer(buf)
        let p = engine.getCompressionProgress()
        XCTAssertGreaterThanOrEqual(p.elapsedSeconds, 0)
    }

    func testMP3FinalizeProvidesEncodingTimeOrSkips() throws {
        let cfg = CompressionConfiguration(format: .mp3, bitrate: 128, quality: .medium, enableVBR: false, sampleRate: 44100, channelCount: 2, enableMultiChannel: false)
        let engine = try LossyCompressionEngine(configuration: cfg)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp3")
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        do {
            _ = try engine.createOutputFile(at: url, format: fmt)
        } catch AudioRecorderError.compressionNotSupported {
            return
        }
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 1024)!
        buf.frameLength = 1024
        _ = try engine.processAudioBuffer(buf)
        let stats = try engine.finalizeCompression()
        XCTAssertGreaterThanOrEqual(stats.encodingTime, 0)
    }

    func testWriteCompressionStatisticsJSONContainsFields() throws {
        let fc = FileController()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try fc.createOutputDirectory(dir)
        let stats = CompressionStatistics(
            sessionId: UUID(),
            format: .aac,
            startTime: Date(),
            endTime: Date(),
            duration: 1,
            originalSize: 1000,
            compressedSize: 500,
            compressionRatio: 0.5,
            fileSizeReduction: 0.5,
            bitrate: 128,
            sampleRate: 44100,
            channelCount: 2,
            enabledVBR: true,
            encodingTime: 0.1,
            averageEncodingSpeed: 1.0,
            cpuUsagePercent: 10,
            memoryUsageMB: 20,
            averageBitrate: 120,
            peakBitrate: 192
        )
        let url = try fc.writeCompressionStatistics(stats, to: dir, baseFilename: "audio.m4a")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["bitrate"] as? Int, 128)
        XCTAssertEqual(json?["enabledVBR"] as? Bool, true)
    }
}
