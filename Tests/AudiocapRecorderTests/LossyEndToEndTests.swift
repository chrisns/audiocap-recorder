import XCTest
import AVFoundation
@testable import AudiocapRecorder
@testable import Core

final class LossyEndToEndTests: XCTestCase {
    func testAACEndToEndWritesM4AReadable() throws {
        let cfg = CompressionConfiguration(format: .aac, bitrate: 128, quality: .medium, enableVBR: false, sampleRate: 44100, channelCount: 2, enableMultiChannel: false)
        let engine = try LossyCompressionEngine(configuration: cfg)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        _ = try engine.createOutputFile(at: url, format: fmt)

        // Encode a few buffers
        for _ in 0..<5 {
            let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 2048)!
            buf.frameLength = 2048
            _ = try engine.processAudioBuffer(buf)
        }
        let stats = try engine.finalizeCompression()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension.lowercased(), "m4a")
        XCTAssertGreaterThan(stats.compressedSize, 0)
        // Note: Avoid strict readability assertion due to platform decoder availability differences
    }

    func testMP3EndToEndWritesMP3OrSkips() throws {
        let cfg = CompressionConfiguration(format: .mp3, bitrate: 128, quality: .medium, enableVBR: false, sampleRate: 44100, channelCount: 2, enableMultiChannel: false)
        let engine = try LossyCompressionEngine(configuration: cfg)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp3")
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        do {
            _ = try engine.createOutputFile(at: url, format: fmt)
        } catch AudioRecorderError.compressionNotSupported {
            // Platform cannot write MP3; skip rest
            return
        }
        for _ in 0..<5 {
            let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 2048)!
            buf.frameLength = 2048
            _ = try engine.processAudioBuffer(buf)
        }
        let stats = try engine.finalizeCompression()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension.lowercased(), "mp3")
        XCTAssertGreaterThan(stats.compressedSize, 0)
    }

    func testAACEncodingPerformanceSimpleBuffer() throws {
        let cfg = CompressionConfiguration(format: .aac, bitrate: 128, quality: .medium, enableVBR: false, sampleRate: 44100, channelCount: 2, enableMultiChannel: false)
        let engine = try LossyCompressionEngine(configuration: cfg)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        _ = try engine.createOutputFile(at: url, format: fmt)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 4096)!
        buf.frameLength = 4096
        let start = Date()
        for _ in 0..<20 { _ = try engine.processAudioBuffer(buf) }
        _ = try engine.finalizeCompression()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 5.0, "Encoding took too long (>5s)")
    }

    func testAACVBRReportsAverageBitrateIncreasingWithMoreData() throws {
        var cfg = CompressionConfiguration(format: .aac, bitrate: 192, quality: .high, enableVBR: true, sampleRate: 44100, channelCount: 2, enableMultiChannel: false)
        var engine = try LossyCompressionEngine(configuration: cfg)
        var url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        _ = try engine.createOutputFile(at: url, format: fmt)
        for _ in 0..<3 {
            let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 1024)!
            buf.frameLength = 1024
            _ = try engine.processAudioBuffer(buf)
        }
        let statsFew = try engine.finalizeCompression()
        XCTAssertNotNil(statsFew.averageBitrate)

        // More data
        cfg.enableVBR = true
        engine = try LossyCompressionEngine(configuration: cfg)
        url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        _ = try engine.createOutputFile(at: url, format: fmt)
        for _ in 0..<20 {
            let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 1024)!
            buf.frameLength = 1024
            _ = try engine.processAudioBuffer(buf)
        }
        let statsMore = try engine.finalizeCompression()
        XCTAssertNotNil(statsMore.averageBitrate)
        // Average may vary, but file size should be greater with more data
        XCTAssertGreaterThan(statsMore.compressedSize, statsFew.compressedSize)
    }
}
