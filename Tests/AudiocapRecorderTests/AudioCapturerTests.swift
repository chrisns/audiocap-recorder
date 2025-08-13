import XCTest
 import AudiocapRecorder
private final class DeniedPermissionManager: PermissionManaging {
    func checkScreenRecordingPermission() -> Bool { false }
    func requestScreenRecordingPermission() {}
    func checkMicrophonePermission() -> Bool { false }
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) { completion(false) }
    func displayPermissionInstructions(for type: AudioRecorderError.PermissionType) {}
}

final class AudioCapturerTests: XCTestCase {
    func testStartCaptureWithoutPermissionThrows() async {
        let capturer = AudioCapturer(permissionManager: DeniedPermissionManager())
        await XCTAssertThrowsErrorAsync(try await capturer.startCapture(for: [])) { error in
            guard case AudioRecorderError.permissionDenied(.screenRecording) = error else {
                XCTFail("Expected permissionDenied(.screenRecording), got: \(error)")
                return
            }
        }
    }
}

// Helper to assert async throws
func XCTAssertThrowsErrorAsync<T>(_ expression: @autoclosure @escaping () async throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line, _ errorHandler: (Error) -> Void = { _ in }) async {
    do {
        _ = try await expression()
        XCTFail("Expected throw", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
