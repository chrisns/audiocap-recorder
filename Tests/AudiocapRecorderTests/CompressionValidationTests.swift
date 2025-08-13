import XCTest
 import AudiocapRecorder
final class CompressionValidationTests: XCTestCase {
    func testIntegrityDetectsMissingOrEmptyFile() {
        let v = CompressionValidator()
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let r = v.validateFileIntegrity(url: tmp, format: .aac)
        XCTAssertFalse(r.isValid)
        XCTAssertGreaterThan(r.issues.count, 0)
    }

    func testMetadataConsistency() {
        let v = CompressionValidator()
        let stats = CompressionStatistics(
            sessionId: UUID(),
            format: .aac,
            startTime: Date(),
            endTime: Date().addingTimeInterval(1),
            duration: 1,
            originalSize: 1000,
            compressedSize: 500,
            compressionRatio: 0.5,
            fileSizeReduction: 0.5,
            bitrate: 128,
            sampleRate: 44100,
            channelCount: 2,
            enabledVBR: false,
            encodingTime: 0.5,
            averageEncodingSpeed: 1.0,
            cpuUsagePercent: 10,
            memoryUsageMB: 20,
            averageBitrate: nil,
            peakBitrate: nil
        )
        let r = v.validateMetadataConsistency(stats)
        XCTAssertTrue(r.isValid)
    }

    func testEfficiencyTolerance() {
        let v = CompressionValidator()
        let stats = CompressionStatistics(
            sessionId: UUID(),
            format: .aac,
            startTime: Date(),
            endTime: Date().addingTimeInterval(10),
            duration: 10,
            originalSize: 0,
            compressedSize: 200_000, // ~160KB expected at 128 kbps
            compressionRatio: 0,
            fileSizeReduction: 0,
            bitrate: 128,
            sampleRate: 44100,
            channelCount: 2,
            enabledVBR: false,
            encodingTime: 10,
            averageEncodingSpeed: 0,
            cpuUsagePercent: 0,
            memoryUsageMB: 0,
            averageBitrate: nil,
            peakBitrate: nil
        )
        let r = v.validateEfficiency(stats: stats)
        XCTAssertTrue(r.isValid)
    }

    func testVBRAverageBitrateCheck() {
        let v = CompressionValidator()
        let stats = CompressionStatistics(
            sessionId: UUID(),
            format: .aac,
            startTime: Date(),
            endTime: Date().addingTimeInterval(10),
            duration: 10,
            originalSize: 0,
            compressedSize: 180_000,
            compressionRatio: 0,
            fileSizeReduction: 0,
            bitrate: 192,
            sampleRate: 44100,
            channelCount: 2,
            enabledVBR: true,
            encodingTime: 10,
            averageEncodingSpeed: 0,
            cpuUsagePercent: 0,
            memoryUsageMB: 0,
            averageBitrate: 144,
            peakBitrate: 256
        )
        let r = v.validateAverageBitrate(stats: stats)
        XCTAssertTrue(r.isValid)
    }
}
