import XCTest
@testable import AudiocapRecorder

final class CompressionModelsTests: XCTestCase {
    func testCompressionFormatFileExtensionMapping() {
        XCTAssertEqual(CompressionConfiguration.CompressionFormat.aac.fileExtension, "m4a")
        XCTAssertEqual(CompressionConfiguration.CompressionFormat.mp3.fileExtension, "mp3")
        XCTAssertEqual(CompressionConfiguration.CompressionFormat.alac.fileExtension, "m4a")
        XCTAssertEqual(CompressionConfiguration.CompressionFormat.uncompressed.fileExtension, "caf")
    }

    func testCompressionQualityBitrates() {
        XCTAssertEqual(CompressionConfiguration.CompressionQuality.low.bitrate, 64)
        XCTAssertEqual(CompressionConfiguration.CompressionQuality.medium.bitrate, 128)
        XCTAssertEqual(CompressionConfiguration.CompressionQuality.high.bitrate, 192)
        XCTAssertEqual(CompressionConfiguration.CompressionQuality.maximum.bitrate, 256)
    }

    func testCompressionConfigurationCodableRoundTrip() throws {
        let config = CompressionConfiguration(
            format: .aac,
            bitrate: 192,
            quality: .high,
            enableVBR: true,
            sampleRate: 44100,
            channelCount: 2,
            enableMultiChannel: false
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(CompressionConfiguration.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testCompressionStatisticsCodableRoundTrip() throws {
        let stats = CompressionStatistics(
            sessionId: UUID(),
            format: .aac,
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            endTime: Date(timeIntervalSince1970: 1_700_000_010),
            duration: 10,
            originalSize: 1_000_000,
            compressedSize: 300_000,
            compressionRatio: 0.3,
            fileSizeReduction: 0.7,
            bitrate: 192,
            sampleRate: 44100,
            channelCount: 2,
            enabledVBR: true,
            encodingTime: 0.5,
            averageEncodingSpeed: 5.0,
            cpuUsagePercent: 12.3,
            memoryUsageMB: 45.6,
            averageBitrate: 180,
            peakBitrate: 256
        )
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(CompressionStatistics.self, from: data)
        XCTAssertEqual(decoded, stats)
        XCTAssertEqual(decoded.fileSizeReductionPercentage, 70.0, accuracy: 0.001)
    }
}
