import Foundation

public struct ErrorPresenter {
    public init() {}

    public func present(_ error: AudioRecorderError) -> String {
        switch error {
        case .permissionDenied(let type):
            switch type {
            case .screenRecording:
                return "Screen Recording permission is required. Go to System Settings > Privacy & Security > Screen Recording and enable it for this app."
            case .fileSystem:
                return "File System permission error. Check directory permissions or choose another output location."
            case .accessibility:
                return "Accessibility permission may be required to correlate processes. Enable it in System Settings > Privacy & Security > Accessibility."
            case .microphone:
                return "Microphone permission is required when using --capture-inputs. Enable it in System Settings > Privacy & Security > Microphone."
            }
        case .processNotFound(let pattern):
            return "No processes matched pattern: \(pattern). Try a broader regex or verify process names/paths."
        case .audioCaptureFailed(let message):
            return "Audio capture failed: \(message). Verify ScreenCaptureKit availability and permissions."
        case .fileSystemError(let message):
            return "File system error: \(message). Ensure the output directory exists and is writable."
        case .invalidRegex(let pattern):
            return "Invalid regex pattern: \(pattern). Please correct the pattern and try again."
        case .configurationError(let message):
            return "Configuration error: \(message)."
        case .alacNotSupported:
            return "ALAC compression is not supported on this system. Re-run without --alac to use uncompressed CAF."
        case .alacEncodingFailed(let message):
            return "ALAC encoding failed: \(message). The recorder will fall back to uncompressed CAF."
        }
    }
}
