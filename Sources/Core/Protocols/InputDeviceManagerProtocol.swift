import Foundation
import AVFoundation

public protocol InputDeviceManagerDelegate: AnyObject {
    func deviceConnected(_ device: AudioInputDevice, assignedToChannel channel: Int)
    func deviceDisconnected(_ device: AudioInputDevice, fromChannel channel: Int)
    func audioDataReceived(from device: AudioInputDevice, buffer: AVAudioPCMBuffer)
}

public protocol InputDeviceManagerProtocol: AnyObject {
    var delegate: InputDeviceManagerDelegate? { get set }
    func enumerateInputDevices() -> [AudioInputDevice]
    func startMonitoring()
    func stopMonitoring()
    func startCapturing()
    func stopCapturing()
    func currentChannelAssignments() -> [Int: AudioInputDevice]
}

public enum AudioDeviceType: Equatable, Hashable {
    case physical
    case aggregate
    case virtual
    case unknown
}

public struct AudioInputDevice: Equatable, Hashable {
    public let uid: String
    public let name: String
    public let channelCount: Int
    public let sampleRate: Double
    public var assignedChannel: Int?
    public var isConnected: Bool
    public var deviceType: AudioDeviceType
    public var manufacturer: String?

    public init(uid: String, name: String, channelCount: Int, sampleRate: Double, assignedChannel: Int? = nil, isConnected: Bool = true, deviceType: AudioDeviceType = .unknown, manufacturer: String? = nil) {
        self.uid = uid
        self.name = name
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self.assignedChannel = assignedChannel
        self.isConnected = isConnected
        self.deviceType = deviceType
        self.manufacturer = manufacturer
    }
}
