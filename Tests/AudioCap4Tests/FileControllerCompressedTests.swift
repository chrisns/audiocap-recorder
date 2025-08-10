import XCTest
import AVFoundation
@testable import AudioCap4

final class FileControllerCompressedTests: XCTestCase {
    func testCreateCompressedFileM4AAndMP3() throws {
        let fc = FileController()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try fc.createOutputDirectory(dir)
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let m4a = try fc.createCompressedFile(in: dir, format: .aac, audioFormat: fmt)
        XCTAssertTrue(m4a.url.path.lowercased().hasSuffix(".m4a"))
        // MP3 writing may not be supported on all systems; allow error
        do {
            let mp3 = try fc.createCompressedFile(in: dir, format: .mp3, audioFormat: fmt)
            XCTAssertTrue(mp3.url.path.lowercased().hasSuffix(".mp3"))
        } catch {
            // acceptable fallback if unsupported
        }
    }

    func testWriteCompressionStatistics() throws {
        let fc = FileController()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        try fc.createOutputDirectory(dir)
        let stats = CompressionStatistics(
            sessionId: UUID(),
            format: .aac,
            startTime: Date(),
            endTime: Date(),
            duration: 1,
            originalSize: 1000,
            compressedSize: 500,
            compressionRatio: 0.5,
            fileSizeReduction: 0.5,
            bitrate: 128,
            sampleRate: 44100,
            channelCount: 2,
            enabledVBR: true,
            encodingTime: 0.1,
            averageEncodingSpeed: 1.0,
            cpuUsagePercent: 10,
            memoryUsageMB: 20,
            averageBitrate: 120,
            peakBitrate: 192
        )
        let url = try fc.writeCompressionStatistics(stats, to: dir, baseFilename: "test.m4a")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testEstimatedDiskSpaceRemaining() {
        let fc = FileController()
        let dir = FileManager.default.temporaryDirectory.path
        let bytes = fc.estimatedDiskSpaceRemaining(at: dir)
        XCTAssertNotEqual(bytes, 0)
    }
}
