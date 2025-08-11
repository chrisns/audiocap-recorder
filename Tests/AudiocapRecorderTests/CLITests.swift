import XCTest
@testable import AudiocapRecorder

final class CLITests: XCTestCase {
    func testCLIParsesValidArguments() throws {
        let cli = try AudioRecorderCLI.parse(["com.*chrome", "--output-directory", "/tmp", "--verbose"])        
        XCTAssertEqual(cli.processRegex, "com.*chrome")
        XCTAssertEqual(cli.outputDirectory, "/tmp")
        XCTAssertTrue(cli.verbose)
        XCTAssertFalse(cli.captureInputs)
        XCTAssertFalse(cli.enableALAC)
        XCTAssertFalse(cli.enableAAC)
        XCTAssertFalse(cli.enableMP3)
    }

    func testCLIParsesCaptureInputsLongFlag() throws {
        let cli = try AudioRecorderCLI.parse(["Spotify|Music", "--capture-inputs"])        
        XCTAssertTrue(cli.captureInputs)
        XCTAssertFalse(cli.enableALAC)
    }

    func testCLIParsesCaptureInputsShortFlag() throws {
        let cli = try AudioRecorderCLI.parse(["Spotify|Music", "-c"])        
        XCTAssertTrue(cli.captureInputs)
        XCTAssertFalse(cli.enableALAC)
    }

    func testCLIParsesALACLongFlag() throws {
        let cli = try AudioRecorderCLI.parse(["Spotify|Music", "--alac"])        
        XCTAssertTrue(cli.enableALAC)
        XCTAssertFalse(cli.captureInputs)
    }

    func testCLIParsesALACShortFlag() throws {
        let cli = try AudioRecorderCLI.parse(["Spotify|Music", "-a"])        
        XCTAssertTrue(cli.enableALAC)
        XCTAssertFalse(cli.captureInputs)
    }

    func testCLIRejectsInvalidRegex() {
        XCTAssertThrowsError(try AudioRecorderCLI.parse(["[invalid"])) { error in
            XCTAssertTrue(String(describing: error).contains("Invalid regex pattern"))
        }
    }

    func testCLIRequiresPatternArgument() {
        XCTAssertThrowsError(try AudioRecorderCLI.parse([]))
    }

    // MARK: - Lossy compression flags
    func testCLIParsesAACFlag() throws {
        let cli = try AudioRecorderCLI.parse(["Music", "--aac"])        
        XCTAssertTrue(cli.enableAAC)
        XCTAssertFalse(cli.enableMP3)
        XCTAssertFalse(cli.enableALAC)
    }

    func testCLIParsesMP3Flag() throws {
        let cli = try AudioRecorderCLI.parse(["Music", "--mp3"])        
        XCTAssertTrue(cli.enableMP3)
        XCTAssertFalse(cli.enableAAC)
        XCTAssertFalse(cli.enableALAC)
    }

    func testCLIParsesBitrate() throws {
        let cli = try AudioRecorderCLI.parse(["Music", "--aac", "--bitrate", "192"])        
        XCTAssertEqual(cli.bitrate, 192)
    }

    func testCLIParsesQuality() throws {
        let cli = try AudioRecorderCLI.parse(["Music", "--aac", "--quality", "high"])        
        XCTAssertEqual(cli.quality, .high)
    }

    func testCLIParsesVBRForAAC() throws {
        let cli = try AudioRecorderCLI.parse(["Music", "--aac", "--vbr"])        
        XCTAssertTrue(cli.vbr)
    }

    func testCLIParsesSampleRate() throws {
        let cli = try AudioRecorderCLI.parse(["Music", "--mp3", "--sample-rate", "44100"])        
        XCTAssertEqual(cli.sampleRate, 44100)
    }

    func testCLIRejectsMultipleCompressionModes() {
        XCTAssertThrowsError(try AudioRecorderCLI.parse(["Music", "--alac", "--aac"]))
        XCTAssertThrowsError(try AudioRecorderCLI.parse(["Music", "--aac", "--mp3"]))
    }

    func testCLIRejectsBitrateWithoutLossyFormat() {
        XCTAssertThrowsError(try AudioRecorderCLI.parse(["Music", "--bitrate", "128"]))
    }

    func testCLIRejectsQualityWithoutLossyFormat() {
        XCTAssertThrowsError(try AudioRecorderCLI.parse(["Music", "--quality", "medium"]))
    }

    func testCLIRejectsBothQualityAndBitrate() {
        XCTAssertThrowsError(try AudioRecorderCLI.parse(["Music", "--aac", "--quality", "low", "--bitrate", "96"]))
    }

    func testCLIRejectsVBRWithoutAAC() {
        XCTAssertThrowsError(try AudioRecorderCLI.parse(["Music", "--mp3", "--vbr"]))
        XCTAssertThrowsError(try AudioRecorderCLI.parse(["Music", "--alac", "--vbr"]))
    }

    func testCLIRejectsInvalidSampleRate() {
        XCTAssertThrowsError(try AudioRecorderCLI.parse(["Music", "--aac", "--sample-rate", "12345"]))
    }

    func testCLIRejectsSampleRateWithoutLossyFormat() {
        XCTAssertThrowsError(try AudioRecorderCLI.parse(["Music", "--sample-rate", "48000"]))
    }
}
