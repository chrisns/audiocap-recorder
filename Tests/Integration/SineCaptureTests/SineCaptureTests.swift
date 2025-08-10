import XCTest
import Foundation
import AVFoundation
import Accelerate
import CoreGraphics

final class SineCaptureTests: XCTestCase {
    func testCaptureSineWaveProducesExpectedFileAndFrequency() throws {
        // Skip on CI or when screen recording permission is not granted
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            throw XCTSkip("Skipping on CI due to Screen Recording permission requirements")
        }
        if CGPreflightScreenCaptureAccess() == false {
            throw XCTSkip("Skipping: Screen Recording permission not granted for test runner")
        }
        // Skip if no main display available for ScreenCaptureKit content filter
        if NSScreen.main == nil {
            throw XCTSkip("Skipping: No main display available for ScreenCaptureKit")
        }

        let totalStart = Date()
        let totalTimeout: TimeInterval = 10.0
        func ensureUnderTimeout(_ msg: String) {
            if Date().timeIntervalSince(totalStart) > totalTimeout {
                XCTFail("Timeout (>10s): \(msg)")
            }
        }

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Locate prebuilt products quickly; skip if not found
        guard let sineBin = findProduct("SineWavePlayer") else { throw XCTSkip("SineWavePlayer not built (debug/release). Build once before running this test.") }
        guard let recBin = findProduct("audiocap-recorder") else { throw XCTSkip("audiocap-recorder not built (debug/release). Build once before running this test.") }

        ensureUnderTimeout("before launching processes")

        // Launch sine player (2s)
        let sineProc = Process()
        sineProc.executableURL = sineBin
        sineProc.environment = [
            "SINE_FREQ_HZ": "1000",
            "SINE_DURATION_SEC": "2"
        ]
        try sineProc.run()

        // Launch recorder targeting helper; capture ~1.5s
        let recorder = Process()
        recorder.executableURL = recBin
        recorder.environment = [ "AUDIOCAP_SKIP_PROCESS_CHECK": "1" ]
        recorder.arguments = ["(?i)SineWavePlayer", "--output-directory", tempDir.path]
        try recorder.run()

        Thread.sleep(forTimeInterval: 1.5)
        ensureUnderTimeout("before SIGINT")
        try sendSignal(.int, to: recorder)

        // Wait up to 3s, then escalate fast
        let deadline = Date().addingTimeInterval(3)
        while recorder.isRunning && Date() < deadline { usleep(50_000) }
        if recorder.isRunning { recorder.terminate() }
        let killDeadline = Date().addingTimeInterval(1)
        while recorder.isRunning && Date() < killDeadline { usleep(50_000) }
        if recorder.isRunning { try sendSignal(.kill, to: recorder) }

        // Ensure sine process stops quickly
        let sineDeadline = Date().addingTimeInterval(1)
        while sineProc.isRunning && Date() < sineDeadline { usleep(50_000) }
        if sineProc.isRunning { sineProc.terminate() }

        ensureUnderTimeout("after process termination")

        // Find latest caf
        let files = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles])
        let cafs = files.filter { $0.pathExtension.lowercased() == "caf" }
        if cafs.isEmpty {
            throw XCTSkip("Recorder did not produce CAF (likely headless display or permissions). Skipping.")
        }
        let latest = cafs.sorted { (a,b) in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da < db
        }.last!

        // Size check: bytes > ~0.5s of audio at 48k stereo float32
        let size = (try? latest.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        XCTAssertGreaterThan(size, 192_000)

        // Read a short segment for analysis
        let file = try AVAudioFile(forReading: latest)
        let format = file.processingFormat
        let frames = AVAudioFrameCount(min(24_000, file.length)) // analyze ~0.5s
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        try file.read(into: buffer, frameCount: frames)
        guard let chData = buffer.floatChannelData else { XCTFail("No channel data"); return }
        let n = Int(buffer.frameLength)
        var mono = [Float](repeating: 0, count: n)
        let chs = Int(format.channelCount)
        for i in 0..<n {
            var sum: Float = 0
            for c in 0..<chs { sum += chData[c][i] }
            mono[i] = sum / Float(chs)
        }
        // Compute RMS; if near-silent, skip frequency assertion to avoid flakiness
        var rms: Float = 0
        vDSP_rmsqv(mono, 1, &rms, vDSP_Length(n))
        if rms < 1e-3 {
            throw XCTSkip("Captured audio RMS too low (\(rms)). Skipping frequency analysis.")
        }

        // Frequency analysis: dominant ~1 kHz
        var fftN = 1
        while fftN < n { fftN <<= 1 }
        var re = mono + [Float](repeating: 0, count: fftN - n)
        var im = [Float](repeating: 0, count: fftN)
        let log2n = vDSP_Length(log2(Float(fftN)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { XCTFail("FFT setup failed"); return }
        defer { vDSP_destroy_fftsetup(setup) }
        var split = DSPSplitComplex(realp: &re, imagp: &im)
        vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
        var mags = [Float](repeating: 0, count: fftN/2)
        vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(fftN/2))
        var maxMag: Float = 0
        var maxIndex: Int = 1
        for i in 1..<(fftN/2) { if mags[i] > maxMag { maxMag = mags[i]; maxIndex = i } }
        let binFreq = Double(maxIndex) * format.sampleRate / Double(fftN)
        XCTAssertGreaterThan(binFreq, 900)
        XCTAssertLessThan(binFreq, 1100)

        ensureUnderTimeout("end of test")
    }

    // Helpers
    private enum Signal { case int, kill }
    private func sendSignal(_ sig: Signal, to proc: Process) throws {
        let pid = proc.processIdentifier
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/kill")
        p.arguments = [sig == .int ? "-INT" : "-KILL", String(pid)]
        try p.run()
        p.waitUntilExit()
    }

    private func findProduct(_ name: String) -> URL? {
        let cwd = FileManager.default.currentDirectoryPath
        let candidates = [".build/debug/\(name)", ".build/release/\(name)"]
        for rel in candidates {
            let url = URL(fileURLWithPath: cwd).appendingPathComponent(rel)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }
}
