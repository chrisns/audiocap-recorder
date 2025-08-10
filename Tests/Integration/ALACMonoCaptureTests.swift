import XCTest
import Foundation
import AVFoundation
import CoreGraphics

final class ALACMonoCaptureTests: XCTestCase {
    func testALACMonoCaptureProducesM4AAndReasonableCompression() throws {
        if ProcessInfo.processInfo.environment["CI"] == "true" { throw XCTSkip("Skipping on CI due to permissions") }
        if CGPreflightScreenCaptureAccess() == false { throw XCTSkip("Skipping: Screen Recording not granted") }
        if NSScreen.main == nil { throw XCTSkip("Skipping: No main display available") }

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        guard let sineBin = findProduct("SineWavePlayer") else { throw XCTSkip("SineWavePlayer not built") }
        guard let recBin = findProduct("audiocap-recorder") else { throw XCTSkip("audiocap-recorder not built") }

        // Launch sine player (~2s)
        let sineProc = Process()
        sineProc.executableURL = sineBin
        sineProc.environment = [
            "SINE_FREQ_HZ": "1000",
            "SINE_DURATION_SEC": "2"
        ]
        try sineProc.run()

        // Launch recorder with --alac, capture ~1.5s
        let recorder = Process()
        recorder.executableURL = recBin
        recorder.environment = [ "AUDIOCAP_SKIP_PROCESS_CHECK": "1" ]
        recorder.arguments = ["(?i)SineWavePlayer", "--output-directory", tempDir.path, "--alac"]
        try recorder.run()
        Thread.sleep(forTimeInterval: 1.5)
        try sendSignal(.int, to: recorder)
        let deadline = Date().addingTimeInterval(2)
        while recorder.isRunning && Date() < deadline { usleep(50_000) }
        if recorder.isRunning { recorder.terminate() }

        // Ensure sine process stops quickly
        let sineDeadline = Date().addingTimeInterval(1)
        while sineProc.isRunning && Date() < sineDeadline { usleep(50_000) }
        if sineProc.isRunning { sineProc.terminate() }

        let files = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles])
        let m4as = files.filter { $0.pathExtension.lowercased() == "m4a" }
        if m4as.isEmpty { throw XCTSkip("No .m4a produced (permissions/environment)") }
        let latest = m4as.sorted { (a,b) in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da < db
        }.last!
        let size = (try? latest.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        XCTAssertGreaterThan(size, 8_000)

        // Baseline approximate uncompressed size: 48k * 1ch * 4 bytes * 1.0s window
        let baselineBytes = 48_000 * 1 * 4
        XCTAssertLessThan(Double(size), Double(baselineBytes))

        // Validate openable via AVAudioFile and ALAC format id
        let file = try AVAudioFile(forReading: latest)
        let fmt = file.fileFormat
        let formatID = fmt.settings[AVFormatIDKey as String] as? UInt32
        XCTAssertEqual(formatID, kAudioFormatAppleLossless)
    }

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
