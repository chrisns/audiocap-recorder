import Foundation
import AVFoundation

final class InputDeviceManager: InputDeviceManagerProtocol {
    weak var delegate: InputDeviceManagerDelegate?

    private var connectedDevicesByUID: [String: AudioInputDevice] = [:]
    private var channelByUID: [String: Int] = [:] // uid -> channel (3-8)
    private var observers: [NSObjectProtocol] = []

    func enumerateInputDevices() -> [AudioInputDevice] {
        let devices = AVCaptureDevice.devices(for: .audio)
        let mapped: [AudioInputDevice] = devices.map { device in
            // AVFoundation does not expose sample rate or channel count directly here.
            // Use conservative defaults; detailed format handling will occur in capture stage (Task 17).
            AudioInputDevice(
                uid: device.uniqueID,
                name: device.localizedName,
                channelCount: 1,
                sampleRate: 48_000,
                assignedChannel: channelByUID[device.uniqueID],
                isConnected: true
            )
        }
        // Refresh internal device map
        for dev in mapped {
            connectedDevicesByUID[dev.uid] = dev
        }
        // Assign channels and return updated list
        let updated = assignChannels(for: Array(connectedDevicesByUID.values))
        return updated
    }

    func startMonitoring() {
        let center = NotificationCenter.default
        let conn = center.addObserver(forName: .AVCaptureDeviceWasConnected, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            guard let device = note.object as? AVCaptureDevice, device.hasMediaType(.audio) else { return }
            let audioDev = AudioInputDevice(
                uid: device.uniqueID,
                name: device.localizedName,
                channelCount: 1,
                sampleRate: 48_000,
                assignedChannel: nil,
                isConnected: true
            )
            self.connectedDevicesByUID[audioDev.uid] = audioDev
            let updated = self.assignChannels(for: Array(self.connectedDevicesByUID.values))
            if let assigned = updated.first(where: { $0.uid == audioDev.uid })?.assignedChannel {
                self.delegate?.deviceConnected(audioDev, assignedToChannel: assigned)
            }
        }
        let disconn = center.addObserver(forName: .AVCaptureDeviceWasDisconnected, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            guard let device = note.object as? AVCaptureDevice, device.hasMediaType(.audio) else { return }
            let uid = device.uniqueID
            let previousChannel = self.channelByUID[uid]
            self.connectedDevicesByUID.removeValue(forKey: uid)
            self.channelByUID.removeValue(forKey: uid)
            _ = self.assignChannels(for: Array(self.connectedDevicesByUID.values))
            if let chan = previousChannel {
                let dev = AudioInputDevice(uid: uid, name: device.localizedName, channelCount: 1, sampleRate: 48_000, assignedChannel: nil, isConnected: false)
                self.delegate?.deviceDisconnected(dev, fromChannel: chan)
            }
        }
        observers = [conn, disconn]
    }

    func stopMonitoring() {
        for obs in observers { NotificationCenter.default.removeObserver(obs) }
        observers.removeAll()
    }

    func currentChannelAssignments() -> [Int: AudioInputDevice] {
        var result: [Int: AudioInputDevice] = [:]
        for (uid, channel) in channelByUID {
            if let dev = connectedDevicesByUID[uid] {
                var updated = dev
                updated.assignedChannel = channel
                result[channel] = updated
            }
        }
        return result
    }
}

// MARK: - Channel assignment (3-8)
extension InputDeviceManager {
    /// Assigns channels 3-8 to up to six devices. Keeps previous assignments when possible.
    /// - Returns: Updated device list with `assignedChannel` populated for assigned devices.
    func assignChannels(for devices: [AudioInputDevice]) -> [AudioInputDevice] {
        // Preserve channels for already-assigned devices that are still present
        let presentUIDs = Set(devices.map { $0.uid })
        channelByUID = channelByUID.filter { presentUIDs.contains($0.key) }

        let availableChannels = Array(3...8)
        var usedChannels = Set(channelByUID.values)

        // Assign channels to unassigned devices in deterministic order (by uid)
        let unassignedUIDs = devices
            .map { $0.uid }
            .filter { channelByUID[$0] == nil }
            .sorted()

        for uid in unassignedUIDs {
            guard let nextChannel = availableChannels.first(where: { !usedChannels.contains($0) }) else {
                break // no channels left
            }
            channelByUID[uid] = nextChannel
            usedChannels.insert(nextChannel)
        }

        // Produce updated device list with assignedChannel values
        var updated: [AudioInputDevice] = []
        updated.reserveCapacity(devices.count)
        for var dev in devices {
            dev.assignedChannel = channelByUID[dev.uid]
            updated.append(dev)
        }
        // Refresh device map with updated assignedChannel
        for dev in updated { connectedDevicesByUID[dev.uid] = dev }
        return updated
    }
}
