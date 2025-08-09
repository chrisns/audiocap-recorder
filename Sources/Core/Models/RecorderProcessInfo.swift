import Foundation

public struct RecorderProcessInfo: Codable, Equatable {
    public let pid: pid_t
    public let executableName: String
    public let executablePath: String
    public let bundleIdentifier: String?
    public let startTime: Date
    public var isActive: Bool
    public var audioActivity: AudioActivityLevel

    public init(
        pid: pid_t,
        executableName: String,
        executablePath: String,
        bundleIdentifier: String?,
        startTime: Date,
        isActive: Bool,
        audioActivity: AudioActivityLevel
    ) {
        self.pid = pid
        self.executableName = executableName
        self.executablePath = executablePath
        self.bundleIdentifier = bundleIdentifier
        self.startTime = startTime
        self.isActive = isActive
        self.audioActivity = audioActivity
    }
}

public enum AudioActivityLevel: String, Codable {
    case silent
    case low
    case medium
    case high
}
