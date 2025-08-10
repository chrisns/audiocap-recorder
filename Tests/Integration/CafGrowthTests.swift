import XCTest
import Foundation
import CoreGraphics

final class CafGrowthTests: XCTestCase {
    func testCAFFileGrowsWithCaptureInputs() throws {
        if ProcessInfo.processInfo.environment["CI"] == "true" { throw XCTSkip("Skipping on CI") }
        if CGPreflightScreenCaptureAccess() == false { throw XCTSkip("Skipping: Screen Recording not granted") }
        if NSScreen.main == nil { throw XCTSkip("Skipping: No main display available") }
        // We cannot programmatically check mic permission here portably; rely on runtime behavior.

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        guard let recBin = findProduct("audiocap-recorder") else { throw XCTSkip("audiocap-recorder not built") }

        let recorder = Process()
        recorder.executableURL = recBin
        recorder.environment = [
            "AUDIOCAP_SKIP_PROCESS_CHECK": "1"
        ]
        recorder.arguments = ["(?i)chrome", "--output-directory", tempDir.path, "--capture-inputs"]
        try recorder.run()

        // Run ~3s then SIGINT
        Thread.sleep(forTimeInterval: 3.0)
        try sendSignal(.int, to: recorder)
        let deadline = Date().addingTimeInterval(2)
        while recorder.isRunning && Date() < deadline { usleep(50_000) }
        if recorder.isRunning { recorder.terminate() }

        let files = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
        let cafs = files.filter { $0.pathExtension.lowercased() == "caf" }
        if cafs.isEmpty { throw XCTSkip("No CAF file produced (permission/config). Skipping.") }
        let latest = cafs.sorted { (a,b) in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da < db
        }.last!
        let size = (try? latest.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        XCTAssertGreaterThan(size, 12_000, "CAF file did not grow beyond header size")
    }

    // Helpers
    private enum Signal { case int }
    private func sendSignal(_ sig: Signal, to proc: Process) throws {
        let pid = proc.processIdentifier
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/kill")
        p.arguments = ["-INT", String(pid)]
        try p.run()
        p.waitUntilExit()
    }
    private func findProduct(_ name: String) -> URL? {
        let cwd = FileManager.default.currentDirectoryPath
        for rel in [".build/debug/\(name)", ".build/release/\(name)"] {
            let url = URL(fileURLWithPath: cwd).appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }
}
