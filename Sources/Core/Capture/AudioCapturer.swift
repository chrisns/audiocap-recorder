import Foundation
import ScreenCaptureKit
import AppKit
import AVFoundation

public final class AudioCapturer: NSObject, AudioCapturerProtocol {
    public weak var delegate: AudioCapturerDelegate?

    private let permissionManager: PermissionManaging
    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "audio.capturer.samples")
    private var recordingTimer: RecordingTimer?

    private let fileController: FileControllerProtocol
    private let audioProcessor: AudioProcessorProtocol
    private var outputDirectoryPath: String?

    private var outputFile: AVAudioFile?
    private var outputURL: URL?

    public init(
        permissionManager: PermissionManaging = PermissionManager(),
        fileController: FileControllerProtocol = FileController(),
        audioProcessor: AudioProcessorProtocol = AudioProcessor(),
        outputDirectoryPath: String? = nil
    ) {
        self.permissionManager = permissionManager
        self.fileController = fileController
        self.audioProcessor = audioProcessor
        self.outputDirectoryPath = outputDirectoryPath
        super.init()
    }

    public func setOutputDirectory(_ path: String?) {
        self.outputDirectoryPath = path
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

        // Capture the display; audio is system-wide via ScreenCaptureKit
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: SCStreamOutputType.audio, sampleHandlerQueue: sampleQueue)

        // Prepare output directory and pre-create file with standard format
        let dirURL: URL
        if let path = outputDirectoryPath, !path.isEmpty {
            try? fileController.createOutputDirectory(path)
            dirURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: true)
        } else {
            dirURL = fileController.defaultOutputDirectory()
            try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }
        let fileURL = dirURL.appendingPathComponent(fileController.generateTimestampedFilename())
        self.outputURL = fileURL

        // Initialize output file immediately with 48kHz stereo float format
        let standard = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        do {
            self.outputFile = try AVAudioFile(forWriting: fileURL, settings: standard.settings)
        } catch {
            delegate?.didEncounterError(.fileSystemError(error.localizedDescription))
        }

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
            guard let self = self else { return }
            if let error = error {
                self.delegate?.didEncounterError(.audioCaptureFailed(error.localizedDescription))
            }
            if let url = self.outputURL {
                self.delegate?.didStopRecording(outputFileURL: url)
            }
        }
        self.stream = nil
        self.outputFile = nil
    }
}

extension AudioCapturer: SCStreamOutput, SCStreamDelegate {
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio else { return }
        guard let file = outputFile, let pcm = audioProcessor.processAudioBuffer(sampleBuffer, from: []) else { return }
        do {
            try file.write(from: pcm)
        } catch {
            delegate?.didEncounterError(.fileSystemError(error.localizedDescription))
        }
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
