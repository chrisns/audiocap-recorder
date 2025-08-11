import XCTest
@testable import AudiocapRecorder

final class RecordingWorkflowTests: XCTestCase, AudioCapturerDelegate, ProcessManagerDelegate {
    private var didStart = false
    private var didDurationUpdate: [Int] = []
    private var didEncounterError: AudioRecorderError?

    func testWorkflowWithMocks() async throws {
        let capturer = MockAudioCapturer()
        capturer.delegate = self
        let processManager = MockProcessManager()
        processManager.delegate = self

        // Simulate discovery
        let processes = [
            RecorderProcessInfo(pid: 123, executableName: "Chrome", executablePath: "/Applications/Google Chrome.app", bundleIdentifier: "com.google.Chrome", startTime: Date(), isActive: true, audioActivity: .low)
        ]
        processManager.discovered = processes
        let discovered = try processManager.discoverProcesses(matching: ".*")
        XCTAssertEqual(discovered.count, 1)

        try await capturer.startCapture(for: discovered)
        XCTAssertTrue(didStart)

        // Stop
        capturer.stopCapture()
    }

    // MARK: - AudioCapturerDelegate
    func didStartRecording() { didStart = true }
    func didUpdateRecordingDuration(seconds: Int) { didDurationUpdate.append(seconds) }
    func didStopRecording(outputFileURL: URL) {}
    func didEncounterError(_ error: AudioRecorderError) { didEncounterError = error }

    // MARK: - ProcessManagerDelegate
    func didDiscover(processes: [RecorderProcessInfo]) {}
    func didUpdate(process: RecorderProcessInfo) {}
}
