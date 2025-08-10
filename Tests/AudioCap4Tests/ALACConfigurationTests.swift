import XCTest
import AVFoundation
@testable import AudioCap4

final class ALACConfigurationTests: XCTestCase {
    func testValidateAcceptsTypicalConfig() throws {
        let cfg = ALACConfiguration(sampleRate: 48_000, channelCount: 2, bitDepth: 16, quality: .max)
        XCTAssertNoThrow(try ALACConfigurator.validate(cfg))
        let settings = try ALACConfigurator.alacSettings(for: cfg)
        XCTAssertEqual(settings[AVNumberOfChannelsKey as String] as? UInt32, 2)
        XCTAssertEqual(settings[AVSampleRateKey as String] as? Double, 48_000)
        XCTAssertEqual(settings[AVEncoderBitDepthHintKey as String] as? Int, 16)
    }

    func testValidateRejectsTooManyChannels() {
        let cfg = ALACConfiguration(sampleRate: 48_000, channelCount: 9, bitDepth: 16, quality: .max)
        XCTAssertThrowsError(try ALACConfigurator.validate(cfg)) { error in
            if let err = error as? ALACValidationError {
                switch err {
                case .unsupportedChannelCount(let count):
                    XCTAssertEqual(count, 9)
                default:
                    XCTFail("Unexpected error: \(err)")
                }
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    func testValidateRejectsUnsupportedBitDepth() {
        let cfg = ALACConfiguration(sampleRate: 48_000, channelCount: 2, bitDepth: 20, quality: .max)
        XCTAssertThrowsError(try ALACConfigurator.validate(cfg))
    }

    func testPCMClientFormatIsInterleavedInt16() throws {
        let cfg = ALACConfiguration(sampleRate: 48_000, channelCount: 2, bitDepth: 16, quality: .max)
        let fmt = try ALACConfigurator.pcmClientFormat(for: cfg)
        XCTAssertTrue(fmt.isInterleaved)
        XCTAssertEqual(fmt.commonFormat, .pcmFormatInt16)
    }
}
