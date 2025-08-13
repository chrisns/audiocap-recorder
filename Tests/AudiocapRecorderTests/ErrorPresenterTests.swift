import XCTest
@testable import AudiocapRecorder
@testable import Core

final class ErrorPresenterTests: XCTestCase {
    func testPermissionDeniedMessage() {
        let presenter = ErrorPresenter()
        let msg = presenter.present(.permissionDenied(.screenRecording))
        XCTAssertTrue(msg.contains("Screen Recording permission"))
    }

    func testInvalidRegexMessage() {
        let presenter = ErrorPresenter()
        let msg = presenter.present(.invalidRegex("["))
        XCTAssertTrue(msg.contains("Invalid regex pattern"))
    }

    func testMicrophonePermissionMessage() {
        let presenter = ErrorPresenter()
        let msg = presenter.present(.permissionDenied(.microphone))
        XCTAssertTrue(msg.contains("Microphone permission"))
    }

    func testALACNotSupportedMessage() {
        let presenter = ErrorPresenter()
        let msg = presenter.present(.alacNotSupported)
        XCTAssertTrue(msg.contains("ALAC compression is not supported"))
    }

    func testALACEncodingFailedMessage() {
        let presenter = ErrorPresenter()
        let msg = presenter.present(.alacEncodingFailed("encoder init"))
        XCTAssertTrue(msg.contains("ALAC encoding failed"))
        XCTAssertTrue(msg.contains("fall back"))
    }

    func testCompressionMessages() {
        let presenter = ErrorPresenter()
        let notSupported = presenter.present(.compressionNotSupported("missing encoder"))
        XCTAssertTrue(notSupported.contains("Compression not supported"))
        XCTAssertTrue(notSupported.contains("uncompressed CAF"))

        let invalid = presenter.present(.compressionConfigurationInvalid("bad bitrate"))
        XCTAssertTrue(invalid.contains("Invalid compression configuration"))
        XCTAssertTrue(invalid.contains("--sample-rate"))

        let failed = presenter.present(.compressionEncodingFailed("write error"))
        XCTAssertTrue(failed.contains("Compression encoding failed"))
        XCTAssertTrue(failed.contains("fall back"))
    }
}
