import XCTest
@testable import AudioCap4

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
}
