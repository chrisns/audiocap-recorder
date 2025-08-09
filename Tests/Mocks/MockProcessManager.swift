import Foundation
@testable import AudioCap4

final class MockProcessManager: ProcessManagerProtocol {
    var discovered: [RecorderProcessInfo] = []
    weak var delegate: ProcessManagerDelegate?
    var didStartMonitoring = false

    func discoverProcesses(matching regexPattern: String) throws -> [RecorderProcessInfo] {
        return discovered
    }

    func startMonitoring(delegate: ProcessManagerDelegate) {
        self.delegate = delegate
        didStartMonitoring = true
    }

    func stopMonitoring() {
        didStartMonitoring = false
        delegate = nil
    }

    // Test helper
    func simulateLaunch(_ info: RecorderProcessInfo) {
        delegate?.didUpdate(process: info)
    }
}
