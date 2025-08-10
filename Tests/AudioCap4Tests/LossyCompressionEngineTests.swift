import XCTest
import AVFoundation
@testable import AudioCap4

final class LossyCompressionEngineTests: XCTestCase {
    func testInitWithAACAndProcessProgress() throws {
        let cfg = CompressionConfiguration(format: .aac, bitrate: 128, quality: .medium, enableVBR: true, sampleRate: 44100, channelCount: 2, enableMultiChannel: false)
        let engine = try LossyCompressionEngine(configuration: cfg)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        _ = try engine.createOutputFile(at: url, format: fmt)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 512)!
        buf.frameLength = 512
        _ = try engine.processAudioBuffer(buf)
        let progress = engine.getCompressionProgress()
        XCTAssertGreaterThanOrEqual(progress.bytesProcessed, 1)
        _ = try engine.finalizeCompression()
    }

    func testInitWithMP3AndRejectOtherFormats() throws {
        let cfg = CompressionConfiguration(format: .mp3, bitrate: 128, quality: .medium, enableVBR: false, sampleRate: 44100, channelCount: 2, enableMultiChannel: false)
        _ = try LossyCompressionEngine(configuration: cfg)
        XCTAssertThrowsError(try LossyCompressionEngine(configuration: .init(format: .alac, bitrate: 0, quality: nil, enableVBR: false, sampleRate: 48000, channelCount: 2, enableMultiChannel: false)))
        XCTAssertThrowsError(try LossyCompressionEngine(configuration: .init(format: .uncompressed, bitrate: 0, quality: nil, enableVBR: false, sampleRate: 48000, channelCount: 2, enableMultiChannel: false)))
    }

    func testProgressFieldsAreSensible() throws {
        let cfg = CompressionConfiguration(format: .aac, bitrate: 192, quality: .high, enableVBR: false, sampleRate: 44100, channelCount: 2, enableMultiChannel: false)
        let engine = try LossyCompressionEngine(configuration: cfg)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        _ = try engine.createOutputFile(at: url, format: fmt)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 1024)!
        buf.frameLength = 1024
        _ = try engine.processAudioBuffer(buf)
        let p = engine.getCompressionProgress()
        XCTAssertGreaterThan(p.bytesProcessed, 0)
        XCTAssertGreaterThanOrEqual(p.estimatedTotalBytes, 0)
        XCTAssertGreaterThanOrEqual(p.encodingSpeedMBps, 0)
        XCTAssertGreaterThanOrEqual(p.compressionRatio, 0)
        XCTAssertGreaterThanOrEqual(p.cpuUsagePercent, 0)
    }
}
