import Foundation

public protocol AudioCapturerDelegate: AnyObject {
    func didStartRecording()
    func didUpdateRecordingDuration(seconds: Int)
    func didStopRecording(outputFileURL: URL)
    func didEncounterError(_ error: AudioRecorderError)
}

public protocol AudioCapturerProtocol {
    func startCapture(for processes: [RecorderProcessInfo]) async throws
    func stopCapture()
    var delegate: AudioCapturerDelegate? { get set }
}
