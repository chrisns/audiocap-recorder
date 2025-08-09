import XCTest
import AVFoundation
@testable import AudioCap4

final class AudioProcessorTests: XCTestCase {
    func testMixTwoSineWavesProducesData() {
        let processor = AudioProcessor()
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let frames: AVAudioFrameCount = 4800
        let buffer1 = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer1.frameLength = frames
        let buffer2 = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer2.frameLength = frames

        // Fill both buffers with simple values
        for c in 0..<Int(format.channelCount) {
            let dst1 = buffer1.floatChannelData![c]
            let dst2 = buffer2.floatChannelData![c]
            for i in 0..<Int(frames) {
                dst1[i] = 0.1
                dst2[i] = 0.2
            }
        }

        let mixed = processor.mixAudioStreams([buffer1, buffer2])
        XCTAssertNotNil(mixed)
        if let mixed = mixed {
            let data = processor.convertToWAV(mixed)
            XCTAssertFalse(data.isEmpty)
        }
    }
}
