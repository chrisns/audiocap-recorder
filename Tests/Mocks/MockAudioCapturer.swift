import Foundation
@testable import AudiocapRecorder

final class MockAudioCapturer: AudioCapturerProtocol {
    weak var delegate: AudioCapturerDelegate?
    private(set) var didStart = false
    private(set) var didStop = false

    func startCapture(for processes: [RecorderProcessInfo]) async throws {
        didStart = true
        delegate?.didStartRecording()
    }

    func stopCapture() {
        didStop = true
    }
}
