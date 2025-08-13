import XCTest
import AVFoundation
@testable import AudiocapRecorder
@testable import Core

final class InputDeviceManagerTests: XCTestCase {
    
    // Helper methods
    func createMockDevices(count: Int) -> [AudioInputDevice] {
        return (1...count).map { i in
            AudioInputDevice(uid: "uid\(i)", name: "Device \(i)", channelCount: 1, sampleRate: 48_000)
        }
    }
    
    func assertDeviceAssignment(_ device: AudioInputDevice, channel: Int) {
        XCTAssertNotNil(device.assignedChannel)
        XCTAssertEqual(device.assignedChannel, channel)
    }
    
    func testAssignChannelsUpToSixDevices() {
        let manager = InputDeviceManager()
        let devices = createMockDevices(count: 8)
        let assigned = manager.assignChannels(for: devices)
        
        let dev1 = assigned.first { $0.uid == "uid1" }!
        let dev2 = assigned.first { $0.uid == "uid2" }!
        let dev3 = assigned.first { $0.uid == "uid3" }!
        let dev4 = assigned.first { $0.uid == "uid4" }!
        let dev5 = assigned.first { $0.uid == "uid5" }!
        let dev6 = assigned.first { $0.uid == "uid6" }!
        let dev7 = assigned.first { $0.uid == "uid7" }!
        let dev8 = assigned.first { $0.uid == "uid8" }!
        
        // First 7 devices get channels 2-8
        assertDeviceAssignment(dev1, channel: 2)
        assertDeviceAssignment(dev2, channel: 3)
        assertDeviceAssignment(dev3, channel: 4)
        assertDeviceAssignment(dev4, channel: 5)
        assertDeviceAssignment(dev5, channel: 6)
        assertDeviceAssignment(dev6, channel: 7)
        assertDeviceAssignment(dev7, channel: 8)
        // 8th device gets no channel
        XCTAssertNil(dev8.assignedChannel)
    }
    
    func testMoreThanSevenDevicesExtraIgnored() {
        let manager = InputDeviceManager()
        let devices = createMockDevices(count: 10)
        let assigned = manager.assignChannels(for: devices)
        
        let withChannels = assigned.filter { $0.assignedChannel != nil }
        let withoutChannels = assigned.filter { $0.assignedChannel == nil }
        
        XCTAssertEqual(withChannels.count, 7, "Only 7 devices should get channels")
        XCTAssertEqual(withoutChannels.count, 3, "3 devices should be without channels")
        
        let channels = Set(withChannels.compactMap { $0.assignedChannel })
        XCTAssertEqual(channels, Set(2...8), "Should use channels 2-8")
    }

    func testStableAssignmentsWhenDevicesPersist() {
        let manager = InputDeviceManager()
        let devicesA = ["A", "B", "C", "D"].map { uid in
            AudioInputDevice(uid: uid, name: uid, channelCount: 1, sampleRate: 48_000)
        }
        let first = manager.assignChannels(for: devicesA)
        let map1: [String: Int] = Dictionary(uniqueKeysWithValues: first.compactMap { dev in
            guard let ch = dev.assignedChannel else { return nil }
            return (dev.uid, ch)
        })

        // Add two new devices and remove one existing
        let devicesB = ["A", "B", "C", "E", "F"].map { uid in
            AudioInputDevice(uid: uid, name: uid, channelCount: 1, sampleRate: 48_000)
        }
        let second = manager.assignChannels(for: devicesB)
        let map2: [String: Int] = Dictionary(uniqueKeysWithValues: second.compactMap { dev in
            guard let ch = dev.assignedChannel else { return nil }
            return (dev.uid, ch)
        })

        // Existing devices keep their channels
        XCTAssertEqual(map1["A"]!, map2["A"]!)
        XCTAssertEqual(map1["B"]!, map2["B"]!)
        XCTAssertEqual(map1["C"]!, map2["C"]!)

        // New devices get remaining channels within 3-8
        let newAssigned = [map2["E"], map2["F"]].compactMap { $0 }
        for ch in newAssigned { XCTAssertTrue((3...8).contains(ch)) }
        XCTAssertEqual(Set(newAssigned).count, newAssigned.count) // unique channels
    }

    func testManufacturerKeywordFilteringExcludesAggregateAndVirtual() {
        let manager = InputDeviceManager()
        let devices = [
            AudioInputDevice(uid: "phys", name: "Mic A", channelCount: 1, sampleRate: 48_000, isConnected: true, deviceType: .unknown, manufacturer: "Acme Inc."),
            AudioInputDevice(uid: "agg", name: "Agg Dev", channelCount: 1, sampleRate: 48_000, isConnected: true, deviceType: .unknown, manufacturer: "Aggregate Device"),
            AudioInputDevice(uid: "virt", name: "Virt Dev", channelCount: 1, sampleRate: 48_000, isConnected: true, deviceType: .unknown, manufacturer: "Virtual Audio")
        ]
        // Use assignChannels(for:) as a proxy to invoke internal filtering via manager state update
        // by directly applying the filter for test purposes using a helper in tests-only extension
        let filtered = manager.__test_filterAggregateAndVirtualDevices(devices)
        let uids = Set(filtered.map { $0.uid })
        XCTAssertTrue(uids.contains("phys"))
        XCTAssertFalse(uids.contains("agg"))
        XCTAssertFalse(uids.contains("virt"))
    }

    func testReconnectRestoresPreviousChannelWhenAvailable() {
        let manager = InputDeviceManager()
        
        // X and Y get channels 2 and 3
        let first = manager.assignChannels(for: [
            AudioInputDevice(uid: "X", name: "Mic X", channelCount: 1, sampleRate: 48_000),
            AudioInputDevice(uid: "Y", name: "Mic Y", channelCount: 1, sampleRate: 48_000)
        ])
        let chX1 = first.first { $0.uid == "X" }!.assignedChannel!
        let chY1 = first.first { $0.uid == "Y" }!.assignedChannel!
        XCTAssertEqual(chX1, 2)
        XCTAssertEqual(chY1, 3)

        // X disconnects (remove from list), Y persists
        let second = manager.assignChannels(for: [
            AudioInputDevice(uid: "Y", name: "Mic Y", channelCount: 1, sampleRate: 48_000)
        ])
        let chY2 = second.first { $0.uid == "Y" }!.assignedChannel!
        XCTAssertEqual(chY2, chY1) // Y keeps its channel

        // X reconnects; previous channel for X should be restored if free
        let third = manager.assignChannels(for: [
            AudioInputDevice(uid: "X", name: "Mic X", channelCount: 1, sampleRate: 48_000),
            AudioInputDevice(uid: "Y", name: "Mic Y", channelCount: 1, sampleRate: 48_000)
        ])
        let chX3 = third.first { $0.uid == "X" }!.assignedChannel!
        let chY3 = third.first { $0.uid == "Y" }!.assignedChannel!
        XCTAssertEqual(chX3, chX1)
        XCTAssertEqual(chY3, chY1)
    }
    
    func testInputAudioConvertedToMono() throws {
        // Create a test delegate to capture audio buffers
        class TestDelegate: InputDeviceManagerDelegate {
            var receivedBuffers: [(device: AudioInputDevice, buffer: AVAudioPCMBuffer)] = []
            
            func deviceConnected(_ device: AudioInputDevice, assignedToChannel channel: Int) {}
            func deviceDisconnected(_ device: AudioInputDevice, fromChannel channel: Int) {}
            func audioDataReceived(from device: AudioInputDevice, buffer: AVAudioPCMBuffer) {
                receivedBuffers.append((device, buffer))
            }
        }
        
        let manager = InputDeviceManager()
        let testDelegate = TestDelegate()
        manager.delegate = testDelegate
        
        // Enumerate devices to ensure we have at least one
        let devices = manager.enumerateInputDevices()
        guard !devices.isEmpty else {
            throw XCTSkip("No input devices available for testing")
        }
        
        // Start capturing
        manager.startCapturing()
        
        // Wait briefly for audio to be captured
        let expectation = XCTestExpectation(description: "Audio captured")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Stop capturing
        manager.stopCapturing()
        
        // Verify that all received buffers are mono (1 channel)
        for (device, buffer) in testDelegate.receivedBuffers {
            XCTAssertEqual(buffer.format.channelCount, 1, 
                          "Audio from device \(device.name) should be mono, but has \(buffer.format.channelCount) channels")
            XCTAssertEqual(buffer.format.sampleRate, 48_000, 
                          "Audio from device \(device.name) should be 48kHz")
        }
        
        // If we received any buffers, the test passes
        if testDelegate.receivedBuffers.isEmpty {
            throw XCTSkip("No audio buffers received during test period")
        }
    }
}

// Tests-only exposure of filtering helper
extension InputDeviceManager {
    func __test_filterAggregateAndVirtualDevices(_ devices: [AudioInputDevice]) -> [AudioInputDevice] {
        return filterAggregateAndVirtualDevices(devices)
    }
}
