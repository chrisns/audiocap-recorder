import XCTest
@testable import AudioCap4

final class CompressionAutoSelectorTests: XCTestCase {
    func testAutoSelectForSpeechShortDurationPrefersAAC() {
        let selector = CompressionAutoSelector()
        let opts = CompressionAutoSelector.AutoSelectOptions(content: .speech, durationSeconds: 120, channels: 2, needMaxCompatibility: false)
        let cfg = selector.selectConfiguration(options: opts)
        XCTAssertEqual(cfg.format, .aac)
        XCTAssertTrue([64, 96, 128, 160, 192, 256, 320].contains(cfg.bitrate))
    }

    func testAutoSelectMaxCompatibilityCanChooseMP3OrAAC() {
        let selector = CompressionAutoSelector()
        let opts = CompressionAutoSelector.AutoSelectOptions(content: .music, durationSeconds: 3600, channels: 2, needMaxCompatibility: true)
        let cfg = selector.selectConfiguration(options: opts)
        XCTAssertTrue(cfg.format == .mp3 || cfg.format == .aac)
    }
}
