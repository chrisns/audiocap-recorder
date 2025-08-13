import XCTest
import AVFoundation
@testable import AudiocapRecorder
@testable import Core

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

final class LossyCompressionEngineAdaptiveTests: XCTestCase {
    func testEngineReportsSuggestedBitrate() throws {
        let cfg = CompressionConfiguration(format: .aac, bitrate: 128, quality: nil, enableVBR: true, sampleRate: 48000, channelCount: 2, enableMultiChannel: false)
        let engine = try LossyCompressionEngine(configuration: cfg)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let out = dir.appendingPathComponent("out.m4a")
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        _ = try engine.createOutputFile(at: out, format: fmt)
        // create simple sine buffer
        let frames = 4096
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(frames))!
        buf.frameLength = AVAudioFrameCount(frames)
        let freq = 4000.0
        if let ch = buf.floatChannelData {
            for i in 0..<frames {
                let t = Double(i) / 48000.0
                let v = sin(2 * .pi * freq * t)
                ch[0][i] = Float(v)
                ch[1][i] = Float(v)
            }
        }
        _ = try engine.processAudioBuffer(buf)
        // Access internal suggested bitrate directly
        let suggested = engine.getSuggestedBitrateKbps()
        _ = engine.getCompressionProgress()
        XCTAssertTrue(suggested == nil || suggested! >= 96)
    }
}
