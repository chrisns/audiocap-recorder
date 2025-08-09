import Foundation
import AVFoundation

final class InputDeviceManager: InputDeviceManagerProtocol {
    weak var delegate: InputDeviceManagerDelegate?

    private var connectedDevicesByUID: [String: AudioInputDevice] = [:]
    private var channelByUID: [String: Int] = [:] // uid -> channel (3-8)
    private var previousChannelByUID: [String: Int] = [:] // persistent last-known channel
    private var observers: [NSObjectProtocol] = []

    private var enginesByUID: [String: AVAudioEngine] = [:]
    private var inputNodesByUID: [String: AVAudioInputNode] = [:]

    func enumerateInputDevices() -> [AudioInputDevice] {
        let devices = AVCaptureDevice.devices(for: .audio)
        let mapped: [AudioInputDevice] = devices.map { device in
            AudioInputDevice(
                uid: device.uniqueID,
                name: device.localizedName,
                channelCount: 1,
                sampleRate: 48_000,
                assignedChannel: channelByUID[device.uniqueID],
                isConnected: true
            )
        }
        for dev in mapped { connectedDevicesByUID[dev.uid] = dev }
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
            if let previousChannel { self.previousChannelByUID[uid] = previousChannel }
            self.connectedDevicesByUID.removeValue(forKey: uid)
            self.channelByUID.removeValue(forKey: uid)
            self.stopCapture(forUID: uid)
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

    func startCapturing() {
        for (_, device) in connectedDevicesByUID {
            startCapture(for: device)
        }
    }

    func stopCapturing() {
        for uid in enginesByUID.keys { stopCapture(forUID: uid) }
    }

    func currentChannelAssignments() -> [Int: AudioInputDevice] {
        var result: [Int: AudioInputDevice] = [:]
        for (uid, channel) in channelByUID {
            if var dev = connectedDevicesByUID[uid] {
                dev.assignedChannel = channel
                result[channel] = dev
            }
        }
        return result
    }
}

// MARK: - Channel assignment (3-8)
extension InputDeviceManager {
    func assignChannels(for devices: [AudioInputDevice]) -> [AudioInputDevice] {
        let presentUIDs = Set(devices.map { $0.uid })
        channelByUID = channelByUID.filter { presentUIDs.contains($0.key) }

        let availableChannels = Array(3...8)
        var usedChannels = Set(channelByUID.values)

        // Try to restore previous channels for devices without a current assignment
        let unassignedUIDs = devices
            .map { $0.uid }
            .filter { channelByUID[$0] == nil }
            .sorted()

        // First pass: restore previous channels when free
        for uid in unassignedUIDs {
            if let prev = previousChannelByUID[uid], !usedChannels.contains(prev) {
                channelByUID[uid] = prev
                usedChannels.insert(prev)
            }
        }
        // Second pass: assign first available channels to remaining
        for uid in unassignedUIDs where channelByUID[uid] == nil {
            guard let nextChannel = availableChannels.first(where: { !usedChannels.contains($0) }) else { break }
            channelByUID[uid] = nextChannel
            usedChannels.insert(nextChannel)
        }

        var updated: [AudioInputDevice] = []
        updated.reserveCapacity(devices.count)
        for var dev in devices {
            if let ch = channelByUID[dev.uid] {
                previousChannelByUID[dev.uid] = ch
            }
            dev.assignedChannel = channelByUID[dev.uid]
            updated.append(dev)
        }
        for dev in updated { connectedDevicesByUID[dev.uid] = dev }
        return updated
    }
}

// MARK: - Capture per device
private extension InputDeviceManager {
    func startCapture(for device: AudioInputDevice) {
        guard enginesByUID[device.uid] == nil else { return }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let hwFormat = input.inputFormat(forBus: 0)
        let targetSR: Double = 48_000
        let targetChannels: AVAudioChannelCount = 1
        let targetFormat = AVAudioFormat(standardFormatWithSampleRate: targetSR, channels: targetChannels)!

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: hwFormat) { [weak self] buffer, _ in
            guard let self else { return }
            // Convert to 48kHz mono if needed
            let converted = self.convert(buffer: buffer, to: targetFormat)
            let dev = self.connectedDevicesByUID[device.uid] ?? device
            self.delegate?.audioDataReceived(from: dev, buffer: converted)
        }

        do {
            try engine.start()
            enginesByUID[device.uid] = engine
            inputNodesByUID[device.uid] = input
        } catch {
            // Non-fatal for Task 17 scaffolding
        }
    }

    func stopCapture(forUID uid: String) {
        if let input = inputNodesByUID[uid] { input.removeTap(onBus: 0) }
        if let engine = enginesByUID[uid] { engine.stop() }
        inputNodesByUID.removeValue(forKey: uid)
        enginesByUID.removeValue(forKey: uid)
    }

    func convert(buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer {
        if buffer.format.sampleRate == format.sampleRate && buffer.format.channelCount == format.channelCount {
            return buffer
        }
        let converter = AVAudioConverter(from: buffer.format, to: format)!
        let frameCapacity = AVAudioFrameCount(buffer.frameLength)
        let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)!
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        converter.convert(to: out, error: &error, withInputFrom: inputBlock)
        if let _ = error { return buffer }
        out.frameLength = min(out.frameCapacity, buffer.frameLength)
        return out
    }
}
