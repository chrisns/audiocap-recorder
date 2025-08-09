import Foundation

public protocol ProcessManagerDelegate: AnyObject {
    func didDiscover(processes: [RecorderProcessInfo])
    func didUpdate(process: RecorderProcessInfo)
}

public protocol ProcessManagerProtocol {
    func discoverProcesses(matching regexPattern: String) throws -> [RecorderProcessInfo]
    func startMonitoring(delegate: ProcessManagerDelegate)
    func stopMonitoring()
}
