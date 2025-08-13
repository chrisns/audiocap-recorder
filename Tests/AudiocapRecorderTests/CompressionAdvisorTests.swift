import XCTest
 import Core
final class CompressionAdvisorTests: XCTestCase {
    func testEstimateSizeMatchesBitrate() {
        let adv = CompressionAdvisor()
        let tenSec = adv.estimateSizeBytes(format: .aac, bitrateKbps: 128, durationSeconds: 10)
        XCTAssertGreaterThan(tenSec, 100 * 1024)
        XCTAssertLessThan(tenSec, 300 * 1024)
    }

    func testCompareReturnsEntriesForAACAndMP3() {
        let adv = CompressionAdvisor()
        let cmp = adv.compare(durationSeconds: 60, bitratesKbps: [96, 128])
        XCTAssertEqual(cmp.entries.count, 4)
        let formats = Set(cmp.entries.map { $0.format })
        XCTAssertTrue(formats.contains(.aac))
        XCTAssertTrue(formats.contains(.mp3))
    }

    func testRecommendSpeechVsMusic() {
        let adv = CompressionAdvisor()
        let speech = adv.recommend(content: .speech, durationSeconds: 300, channels: 1, needMaxCompatibility: false)
        XCTAssertEqual(speech.format, .aac)
        XCTAssertEqual(speech.recommendedBitrateKbps, 96)

        let music = adv.recommend(content: .music, durationSeconds: 300, channels: 2, needMaxCompatibility: false)
        XCTAssertEqual(music.recommendedBitrateKbps, 192)
        XCTAssertTrue(music.rationale.contains("Music"))
    }

    func testRecommendMaxCompatibilityUsesMP3ForStereo() {
        let adv = CompressionAdvisor()
        let rec = adv.recommend(content: .mixed, durationSeconds: 1200, channels: 2, needMaxCompatibility: true)
        XCTAssertEqual(rec.format, .mp3)
        XCTAssertTrue(rec.rationale.contains("compatibility"))
    }

    func testRecommendMP3WithMultichannelFallsBackToAAC() {
        let adv = CompressionAdvisor()
        let rec = adv.recommend(content: .mixed, durationSeconds: 1200, channels: 6, needMaxCompatibility: true)
        XCTAssertEqual(rec.format, .aac)
        XCTAssertFalse(rec.warnings.isEmpty)
    }
}
