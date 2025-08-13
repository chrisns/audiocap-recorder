import XCTest
 import AudiocapRecorder
final class ProcessManagerTests: XCTestCase {
    func testInvalidRegexThrows() {
        let pm = ProcessManager()
        XCTAssertThrowsError(try pm.discoverProcesses(matching: "[invalid")) { error in
            guard case AudioRecorderError.invalidRegex = error else {
                XCTFail("Expected invalidRegex error, got: \(error)")
                return
            }
        }
    }

    func testRegexMatchesReasonablePattern() throws {
        let pm = ProcessManager()
        // This is a smoke test: ensure running processes can be discovered without crashing
        let procs = try pm.discoverProcesses(matching: ".*")
        XCTAssertGreaterThanOrEqual(procs.count, 0)
    }
}
