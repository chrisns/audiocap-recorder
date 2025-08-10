import Foundation

public enum AudioRecorderError: LocalizedError, Equatable, Sendable {
    case permissionDenied(PermissionType)
    case processNotFound(String)
    case audioCaptureFailed(String)
    case fileSystemError(String)
    case invalidRegex(String)
    case configurationError(String)
    case alacNotSupported
    case alacEncodingFailed(String)

    public enum PermissionType: Equatable, Sendable {
        case screenRecording
        case fileSystem
        case accessibility
        case microphone
    }

    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let type):
            return "Permission denied: \(type)"
        case .processNotFound(let pattern):
            return "No processes matched pattern: \(pattern)"
        case .audioCaptureFailed(let message):
            return "Audio capture failed: \(message)"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        case .invalidRegex(let pattern):
            return "Invalid regex pattern: \(pattern)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .alacNotSupported:
            return "ALAC compression is not supported on this system configuration."
        case .alacEncodingFailed(let message):
            return "ALAC encoding failed: \(message)"
        }
    }
}
