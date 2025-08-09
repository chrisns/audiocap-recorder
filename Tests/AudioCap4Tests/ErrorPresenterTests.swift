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
}
