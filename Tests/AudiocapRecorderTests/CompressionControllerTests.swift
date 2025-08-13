import XCTest
import AVFoundation
@testable import AudiocapRecorder
@testable import Core

final class CompressionControllerTests: XCTestCase {
    func testInitializeAACValidConfig() throws {
        let ctrl = CompressionController()
        let config = CompressionConfiguration(
            format: .aac,
            bitrate: 128,
            quality: .medium,
            enableVBR: true,
            sampleRate: 44100,
            channelCount: 2,
            enableMultiChannel: false
        )
        try ctrl.initialize(with: config)
        XCTAssertNotNil(ctrl)
    }

    func testRejectsInvalidBitrateForLossy() {
        let ctrl = CompressionController()
        let config = CompressionConfiguration(
            format: .aac,
            bitrate: 32, // too low
            quality: .low,
            enableVBR: false,
            sampleRate: 44100,
            channelCount: 2,
            enableMultiChannel: false
        )
        do {
            try ctrl.initialize(with: config)
            XCTFail("Expected invalid bitrate error")
        } catch let err as CompressionControllerError {
            XCTAssertEqual(err, .invalidBitrate(32))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRejectsInvalidSampleRateForLossy() {
        let ctrl = CompressionController()
        let config = CompressionConfiguration(
            format: .aac,
            bitrate: 128,
            quality: .medium,
            enableVBR: true,
            sampleRate: 12345,
            channelCount: 2,
            enableMultiChannel: false
        )
        do {
            try ctrl.initialize(with: config)
            XCTFail("Expected invalid sample rate error")
        } catch let err as CompressionControllerError {
            switch err {
            case .invalidSampleRate(let sr): XCTAssertEqual(Int(sr), 12345)
            default: XCTFail("Wrong error: \(err)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMP3RejectsMoreThanStereoAndVBR() {
        let ctrl = CompressionController()
        var config = CompressionConfiguration(
            format: .mp3,
            bitrate: 192,
            quality: .high,
            enableVBR: false,
            sampleRate: 44100,
            channelCount: 6,
            enableMultiChannel: true
        )
        XCTAssertThrowsError(try ctrl.initialize(with: config))

        config = CompressionConfiguration(
            format: .mp3,
            bitrate: 192,
            quality: .high,
            enableVBR: true,
            sampleRate: 44100,
            channelCount: 2,
            enableMultiChannel: false
        )
        do {
            try ctrl.initialize(with: config)
            XCTFail("Expected VBR not supported error for MP3")
        } catch let err as CompressionControllerError {
            switch err {
            case .vbrNotSupported(let fmt): XCTAssertEqual(fmt, .mp3)
            default: XCTFail("Wrong error: \(err)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateOutputFileWithPassthrough() throws {
        let ctrl = CompressionController()
        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
        let config = CompressionConfiguration(
            format: .uncompressed,
            bitrate: 0,
            quality: nil,
            enableVBR: false,
            sampleRate: 48000,
            channelCount: 2,
            enableMultiChannel: false
        )
        try ctrl.initialize(with: config)
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        _ = try ctrl.createOutputFile(at: fileURL, format: fmt)
    }

    func testInitializeWithCompatibilitySanitizesAndCreatesEngine() throws {
        let ctrl = CompressionController()
        // Intentionally invalid: bitrate too low and invalid sample rate; should be clamped/sanitized
        let bad = CompressionConfiguration(
            format: .aac,
            bitrate: 32,
            quality: nil,
            enableVBR: true,
            sampleRate: 12345,
            channelCount: 2,
            enableMultiChannel: false
        )
        XCTAssertNoThrow(try ctrl.initializeWithCompatibility(bad))
        // Now MP3 with invalid params should end up sanitized to stereo, no VBR
        let badMP3 = CompressionConfiguration(
            format: .mp3,
            bitrate: 512,
            quality: nil,
            enableVBR: true,
            sampleRate: 96000,
            channelCount: 6,
            enableMultiChannel: true
        )
        XCTAssertNoThrow(try ctrl.initializeWithCompatibility(badMP3))
    }
}
