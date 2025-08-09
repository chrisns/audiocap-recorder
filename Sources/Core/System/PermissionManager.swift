import Foundation
import CoreGraphics

public struct PermissionManager {
    public init() {}

    public func checkScreenRecordingPermission() -> Bool {
        // Returns true if permission has already been granted
        return CGPreflightScreenCaptureAccess()
    }

    public func requestScreenRecordingPermission() {
        _ = CGRequestScreenCaptureAccess()
    }

    public func displayPermissionInstructions(for type: AudioRecorderError.PermissionType) {
        switch type {
        case .screenRecording:
            print("Screen Recording permission is required for audio capture via ScreenCaptureKit.")
            print("Open System Settings > Privacy & Security > Screen Recording.")
            print("Enable permission for your terminal or the built binary (audiocap-recorder). Then restart the app.")
        case .fileSystem:
            print("File System permission may be required to write recordings to the chosen directory.")
        case .accessibility:
            print("Accessibility permission may be required for process correlation features.")
        }
    }
}
