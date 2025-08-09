import XCTest
@testable import AudioCap4

final class CLITests: XCTestCase {
    func testCLIParsesValidArguments() throws {
        let cli = try AudioRecorderCLI.parse(["com.*chrome", "--output-directory", "/tmp", "--verbose"])        
        XCTAssertEqual(cli.processRegex, "com.*chrome")
        XCTAssertEqual(cli.outputDirectory, "/tmp")
        XCTAssertTrue(cli.verbose)
        XCTAssertFalse(cli.captureInputs)
    }

    func testCLIParsesCaptureInputsLongFlag() throws {
        let cli = try AudioRecorderCLI.parse(["Spotify|Music", "--capture-inputs"])        
        XCTAssertTrue(cli.captureInputs)
    }

    func testCLIParsesCaptureInputsShortFlag() throws {
        let cli = try AudioRecorderCLI.parse(["Spotify|Music", "-c"])        
        XCTAssertTrue(cli.captureInputs)
    }

    func testCLIRejectsInvalidRegex() {
        XCTAssertThrowsError(try AudioRecorderCLI.parse(["[invalid"])) { error in
            XCTAssertTrue(String(describing: error).contains("Invalid regex pattern"))
        }
    }

    func testCLIRequiresPatternArgument() {
        XCTAssertThrowsError(try AudioRecorderCLI.parse([]))
    }
}
