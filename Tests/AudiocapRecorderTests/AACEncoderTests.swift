import XCTest
import AVFoundation
 import Core
final class AACEncoderTests: XCTestCase {
    func testCreateAACSettingsCBRAndVBR() throws {
        let enc = AACEncoder()
        let cbr = enc.createAACSettings(bitrate: 128, sampleRate: 44100, channelCount: 2, enableVBR: false)
        XCTAssertEqual(cbr[AVFormatIDKey] as? UInt32, kAudioFormatMPEG4AAC)
        XCTAssertEqual(cbr[AVEncoderBitRateStrategyKey] as? String, AVAudioBitRateStrategy_Constant)
        XCTAssertEqual(cbr[AVEncoderBitRateKey] as? Int, 128_000)

        let vbr = enc.createAACSettings(bitrate: 192, sampleRate: 48000, channelCount: 2, enableVBR: true)
        XCTAssertEqual(vbr[AVEncoderBitRateStrategyKey] as? String, AVAudioBitRateStrategy_Variable)
        XCTAssertNotNil(vbr[AVEncoderAudioQualityForVBRKey])
    }

    func testInitializeAndCreateFileAndEncode() throws {
        let enc = AACEncoder()
        let cfg = LossyCompressionConfiguration(format: .aac, bitrate: 128, enableVBR: false, sampleRate: 44100, channelCount: 2, quality: .high)
        try enc.initialize(configuration: cfg)

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let inFmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        _ = try enc.createAudioFile(at: tmp, format: inFmt)

        let buf = AVAudioPCMBuffer(pcmFormat: inFmt, frameCapacity: 1024)!
        buf.frameLength = 1024
        // Fill with zeros; encode should succeed writing to file
        _ = try enc.encode(buffer: buf)

        // Finalize should return stats with config values
        let stats = try enc.finalize()
        XCTAssertEqual(stats.bitrate, 128)
        XCTAssertEqual(Int(stats.sampleRate), 44100)
        XCTAssertEqual(stats.channelCount, 2)
    }

    func testVBRFinalizeReportsAverageBitrate() throws {
        let enc = AACEncoder()
        let cfg = LossyCompressionConfiguration(format: .aac, bitrate: 192, enableVBR: true, sampleRate: 44100, channelCount: 2, quality: .high)
        try enc.initialize(configuration: cfg)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let inFmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        _ = try enc.createAudioFile(at: tmp, format: inFmt)
        let buf = AVAudioPCMBuffer(pcmFormat: inFmt, frameCapacity: 1024)!
        buf.frameLength = 1024
        _ = try enc.encode(buffer: buf)
        let stats = try enc.finalize()
        XCTAssertNotNil(stats.averageBitrate)
    }

    func testSampleRateConversionPathCreatesConverter() throws {
        let enc = AACEncoder()
        // Request encoder sample rate to 48k while input is 44.1k
        try enc.initialize(configuration: .init(format: .aac, bitrate: 128, enableVBR: false, sampleRate: 48000, channelCount: 2, quality: .high))
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let inFmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        _ = try enc.createAudioFile(at: tmp, format: inFmt)
        let buf = AVAudioPCMBuffer(pcmFormat: inFmt, frameCapacity: 2048)!
        buf.frameLength = 2048
        _ = try enc.encode(buffer: buf)
        let stats = try enc.finalize()
        XCTAssertGreaterThan(stats.duration, 0)
    }
}
