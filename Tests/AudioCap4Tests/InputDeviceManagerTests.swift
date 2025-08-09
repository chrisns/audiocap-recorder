import XCTest
@testable import AudioCap4

final class InputDeviceManagerTests: XCTestCase {
    func testAssignChannelsUpToSixDevices() {
        let manager = InputDeviceManager()
        let devices = (1...6).map { i in
            AudioInputDevice(uid: "uid_\(i)", name: "Mic \(i)", channelCount: 1, sampleRate: 48_000)
        }
        let updated = manager.assignChannels(for: devices)
        let mapping = Dictionary(uniqueKeysWithValues: updated.compactMap { dev -> (Int, String)? in
            guard let ch = dev.assignedChannel else { return nil }
            return (ch, dev.uid)
        })
        XCTAssertEqual(mapping.keys.sorted(), Array(3...8))
    }

    func testMoreThanSixDevicesExtraIgnored() {
        let manager = InputDeviceManager()
        let devices = (1...8).map { i in
            AudioInputDevice(uid: "uid_\(i)", name: "Mic \(i)", channelCount: 1, sampleRate: 48_000)
        }
        let updated = manager.assignChannels(for: devices)
        let assigned = updated.filter { $0.assignedChannel != nil }
        XCTAssertEqual(assigned.count, 6)
        let channels = assigned.compactMap { $0.assignedChannel }.sorted()
        XCTAssertEqual(channels, Array(3...8))
        let unassignedUIDs = Set(updated.filter { $0.assignedChannel == nil }.map { $0.uid })
        XCTAssertEqual(unassignedUIDs, Set(["uid_7", "uid_8"]))
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
}
