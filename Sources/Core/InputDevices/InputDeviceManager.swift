import Foundation
import AVFoundation
import CoreAudio

public final class InputDeviceManager: InputDeviceManagerProtocol, @unchecked Sendable {
    public weak var delegate: InputDeviceManagerDelegate?

    private var connectedDevicesByUID: [String: AudioInputDevice] = [:]
    private var channelByUID: [String: Int] = [:] // uid -> channel (3-8)
    private var previousChannelByUID: [String: Int] = [:] // persistent last-known channel
    private var observers: [NSObjectProtocol] = []

    private var enginesByUID: [String: AVAudioEngine] = [:]
    private var inputNodesByUID: [String: AVAudioInputNode] = [:]

    public init() {}

    public func enumerateInputDevices() -> [AudioInputDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        let devices = discoverySession.devices
        let mapped: [AudioInputDevice] = devices.map { device in
            let dev = AudioInputDevice(
                uid: device.uniqueID,
                name: device.localizedName,
                channelCount: 1,
                sampleRate: 48_000,
                assignedChannel: channelByUID[device.uniqueID],
                isConnected: true,
                deviceType: detectDeviceType(forUID: device.uniqueID),
                manufacturer: fetchManufacturer(forUID: device.uniqueID)
            )
            return dev
        }
        let filtered = filterAggregateAndVirtualDevices(mapped)
        for dev in filtered { connectedDevicesByUID[dev.uid] = dev }
        let updated = assignChannels(for: Array(connectedDevicesByUID.values))
        return updated
    }

    public func startMonitoring() {
        let center = NotificationCenter.default
        let conn = center.addObserver(forName: .AVCaptureDeviceWasConnected, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            guard let device = note.object as? AVCaptureDevice, device.hasMediaType(.audio) else { return }
            var audioDev = AudioInputDevice(
                uid: device.uniqueID,
                name: device.localizedName,
                channelCount: 1,
                sampleRate: 48_000,
                assignedChannel: nil,
                isConnected: true,
                deviceType: self.detectDeviceType(forUID: device.uniqueID),
                manufacturer: self.fetchManufacturer(forUID: device.uniqueID)
            )
            // Exclude aggregate/virtual
            if !isPhysicalInputDevice(audioDev) {
                print("Excluding device: \(audioDev.name) [uid=\(audioDev.uid)] type=\(audioDev.deviceType)")
                return
            }
            self.connectedDevicesByUID[audioDev.uid] = audioDev
            let updated = self.assignChannels(for: Array(self.connectedDevicesByUID.values))
            if let assigned = updated.first(where: { $0.uid == audioDev.uid })?.assignedChannel {
                audioDev.assignedChannel = assigned
                self.connectedDevicesByUID[audioDev.uid] = audioDev
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
                let dev = AudioInputDevice(uid: uid, name: device.localizedName, channelCount: 1, sampleRate: 48_000, assignedChannel: nil, isConnected: false, deviceType: .unknown, manufacturer: nil)
                self.delegate?.deviceDisconnected(dev, fromChannel: chan)
            }
        }
        observers = [conn, disconn]
    }

    public func stopMonitoring() {
        for obs in observers { NotificationCenter.default.removeObserver(obs) }
        observers.removeAll()
    }

    public func startCapturing() {
        for (_, device) in connectedDevicesByUID {
            startCapture(for: device)
        }
    }

    public func stopCapturing() {
        for uid in enginesByUID.keys { stopCapture(forUID: uid) }
    }

    public func currentChannelAssignments() -> [Int: AudioInputDevice] {
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

// MARK: - Filtering and type detection
extension InputDeviceManager {
    func isPhysicalInputDevice(_ device: AudioInputDevice) -> Bool {
        return device.deviceType == .physical
    }

    func filterAggregateAndVirtualDevices(_ devices: [AudioInputDevice]) -> [AudioInputDevice] {
        var included: [AudioInputDevice] = []
        for dev in devices {
            switch dev.deviceType {
            case .aggregate:
                print("Excluding aggregate device: \(dev.name) [uid=\(dev.uid)]")
            case .virtual:
                print("Excluding virtual device: \(dev.name) [uid=\(dev.uid)]")
            case .unknown:
                if let mfg = dev.manufacturer?.lowercased(), mfg.contains("aggregate") || mfg.contains("virtual") {
                    print("Excluding device by manufacturer keyword: \(dev.name) [uid=\(dev.uid)] mfg=\(mfg)")
                    continue
                }
                included.append(dev)
            case .physical:
                included.append(dev)
            }
        }
        return included
    }

    func detectDeviceType(forUID uid: String) -> AudioDeviceType {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let deviceID = audioDeviceID(forUID: uid)
        guard deviceID != kAudioObjectUnknown else { return .unknown }
        var transportType: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transportType)
        if status != noErr { return .unknown }
        switch transportType {
        case kAudioDeviceTransportTypeAggregate:
            return .aggregate
        case kAudioDeviceTransportTypeVirtual:
            return .virtual
        default:
            return .physical
        }
    }

    func fetchManufacturer(forUID uid: String) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyManufacturer,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let deviceID = audioDeviceID(forUID: uid)
        guard deviceID != kAudioObjectUnknown else { return nil }
        var size = UInt32(0)
        var status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        if status != noErr || size == 0 { return nil }
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 1)
        defer { buffer.deallocate() }
        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, buffer)
        if status != noErr { return nil }
        let cfstr = buffer.bindMemory(to: CFString.self, capacity: 1).pointee
        return cfstr as String
    }

    func audioDeviceID(forUID uid: String) -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        if status != noErr || size == 0 { return kAudioObjectUnknown }
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        let buffer = UnsafeMutablePointer<AudioObjectID>.allocate(capacity: count)
        defer { buffer.deallocate() }
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, buffer)
        if status != noErr { return kAudioObjectUnknown }
        let devices = Array(UnsafeBufferPointer(start: buffer, count: count))
        for dev in devices {
            if let cfuid = copyDeviceUID(dev) as String?, cfuid == uid {
                return dev
            }
        }
        return kAudioObjectUnknown
    }

    func copyDeviceUID(_ deviceID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(0)
        var status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        if status != noErr || size == 0 { return nil }
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 1)
        defer { buffer.deallocate() }
        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, buffer)
        if status != noErr { return nil }
        let cfstr = buffer.bindMemory(to: CFString.self, capacity: 1).pointee
        return cfstr as String
    }
}

// MARK: - Channel assignment (3-8)
extension InputDeviceManager {
    func assignChannels(for devices: [AudioInputDevice]) -> [AudioInputDevice] {
        let presentUIDs = Set(devices.map { $0.uid })
        channelByUID = channelByUID.filter { presentUIDs.contains($0.key) }

        let availableChannels = Array(2...8)
        var usedChannels = Set(channelByUID.values)

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
            var dev = self.connectedDevicesByUID[device.uid] ?? device
            dev.assignedChannel = self.channelByUID[device.uid] ?? dev.assignedChannel
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
