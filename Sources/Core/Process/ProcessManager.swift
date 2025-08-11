import Foundation
import AppKit

public final class ProcessManager: ProcessManagerProtocol, @unchecked Sendable {
    private weak var delegate: ProcessManagerDelegate?
    private var notificationObservers: [NSObjectProtocol] = []
    private let notificationCenter: NotificationCenter

    public init(notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.notificationCenter = notificationCenter
    }

    public func discoverProcesses(matching regexPattern: String) throws -> [RecorderProcessInfo] {
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: regexPattern)
        } catch {
            throw AudioRecorderError.invalidRegex(regexPattern)
        }

        let runningApps = NSWorkspace.shared.runningApplications
        let now = Date()
        let matched: [RecorderProcessInfo] = runningApps.compactMap { app in
            guard let info = makeProcessInfo(from: app, referenceTime: now) else { return nil }
            if matches(regex: regex, info: info) {
                return info
            }
            return nil
        }
        return matched
    }

    public func startMonitoring(delegate: ProcessManagerDelegate) {
        self.delegate = delegate

        let launchObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard let info = self.makeProcessInfo(from: app, referenceTime: Date()) else { return }
            self.delegate?.didUpdate(process: info)
        }

        let terminateObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard var info = self.makeProcessInfo(from: app, referenceTime: Date()) else { return }
            info.isActive = false
            self.delegate?.didUpdate(process: info)
        }

        notificationObservers.append(contentsOf: [launchObserver, terminateObserver])
    }

    public func stopMonitoring() {
        for obs in notificationObservers {
            notificationCenter.removeObserver(obs)
        }
        notificationObservers.removeAll()
        delegate = nil
    }

    // MARK: - Helpers

    private func makeProcessInfo(from app: NSRunningApplication, referenceTime: Date) -> RecorderProcessInfo? {
        let pid = app.processIdentifier
        let name = app.localizedName ?? ""
        let bundleId = app.bundleIdentifier
        let path = app.bundleURL?.path ?? ""

        if name.isEmpty && path.isEmpty {
            return nil
        }

        return RecorderProcessInfo(
            pid: pid,
            executableName: name,
            executablePath: path,
            bundleIdentifier: bundleId,
            startTime: referenceTime,
            isActive: !app.isTerminated,
            audioActivity: .silent
        )
    }

    private func matches(regex: NSRegularExpression, info: RecorderProcessInfo) -> Bool {
        let haystacks = [info.executableName, info.executablePath, info.bundleIdentifier ?? ""]
        for hay in haystacks where !hay.isEmpty {
            let range = NSRange(hay.startIndex..<hay.endIndex, in: hay)
            if regex.firstMatch(in: hay, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }
}
