import Foundation
import ScreenCaptureKit
import AppKit

public final class AudioCapturer: NSObject, AudioCapturerProtocol {
    public weak var delegate: AudioCapturerDelegate?

    private let permissionManager: PermissionManaging
    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "audio.capturer.samples")
    private var recordingTimer: RecordingTimer?

    public init(permissionManager: PermissionManaging = PermissionManager()) {
        self.permissionManager = permissionManager
        super.init()
    }
}

extension AudioCapturer {
    public func startCapture(for processes: [RecorderProcessInfo]) async throws {
        guard permissionManager.checkScreenRecordingPermission() else {
            throw AudioRecorderError.permissionDenied(.screenRecording)
        }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2
        config.excludesCurrentProcessAudio = true

        let content = try await SCShareableContent.current
        guard let display = preferredDisplay(from: content.displays) else {
            throw AudioRecorderError.configurationError("No display available for content filter")
        }

        let filter = SCContentFilter(display: display, including: [], exceptingWindows: [])

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: SCStreamOutputType.audio, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        self.stream = stream
        delegate?.didStartRecording()

        // Start duration updates with 12-hour max as per requirements
        let maxSeconds = 12 * 60 * 60
        let timer = RecordingTimer(queue: .main, tickInterval: 1.0, maxDurationSeconds: maxSeconds)
        timer.start(onTick: { [weak self] seconds in
            self?.delegate?.didUpdateRecordingDuration(seconds: seconds)
        }, onCompleted: { [weak self] in
            self?.stopCapture()
        })
        self.recordingTimer = timer
    }

    public func stopCapture() {
        recordingTimer?.stop()
        recordingTimer = nil

        guard let stream = stream else { return }
        stream.stopCapture { [weak self] error in
            if let error = error {
                self?.delegate?.didEncounterError(.audioCaptureFailed(error.localizedDescription))
            }
        }
        self.stream = nil
    }
}

extension AudioCapturer: SCStreamOutput, SCStreamDelegate {
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio else { return }
    }

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        delegate?.didEncounterError(.audioCaptureFailed(error.localizedDescription))
    }
}

// MARK: - Helpers
private extension AudioCapturer {
    func preferredDisplay(from displays: [SCDisplay]) -> SCDisplay? {
        if let mainScreen = NSScreen.main, let id = mainScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            return displays.first { $0.displayID == id }
        }
        return displays.first
    }
}
