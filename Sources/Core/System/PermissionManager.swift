import Foundation
import CoreGraphics
import AVFoundation

public protocol PermissionManaging {
    func checkScreenRecordingPermission() -> Bool
    func requestScreenRecordingPermission()
    func checkMicrophonePermission() -> Bool
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void)
    func displayPermissionInstructions(for type: AudioRecorderError.PermissionType)
}

public struct PermissionManager: PermissionManaging {
    public init() {}

    public func checkScreenRecordingPermission() -> Bool {
        // Returns true if permission has already been granted
        return CGPreflightScreenCaptureAccess()
    }

    public func requestScreenRecordingPermission() {
        _ = CGRequestScreenCaptureAccess()
    }

    public func checkMicrophonePermission() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .authorized
    }

    public func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            completion(granted)
        }
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
        case .microphone:
            print("Microphone permission is required to capture audio input devices when using --capture-inputs.")
            print("Open System Settings > Privacy & Security > Microphone and enable access for your terminal/Xcode.")
        }
    }
}
