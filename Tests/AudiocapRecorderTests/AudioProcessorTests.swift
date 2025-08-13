import XCTest
import AVFoundation
 import Core

final class AudioProcessorTests: XCTestCase {
    func makeSineBuffer(freq: Double, seconds: Double = 0.1, sampleRate: Double = 48_000, channels: AVAudioChannelCount = 1) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(seconds * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let count = Int(frames)
        let twoPi = 2.0 * Double.pi
        if let ch = buffer.floatChannelData {
            for c in 0..<Int(channels) {
                for i in 0..<count {
                    let t = Double(i) / sampleRate
                    ch[c][i] = Float(sin(twoPi * freq * t))
                }
            }
        }
        return buffer
    }

    func testMixTwoSineWavesProducesData() {
        let proc = AudioProcessor()
        let a = makeSineBuffer(freq: 440, channels: 2)
        let b = makeSineBuffer(freq: 660, channels: 2)
        let mixed = proc.mixAudioStreams([a, b])
        XCTAssertNotNil(mixed)
        XCTAssertGreaterThan(mixed!.frameLength, 0)
    }

    func testCombineProcessAndInputsToEightChannels() throws {
        // Skip if 8-channel float32 non-interleaved buffers are not supported in this environment
        guard let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 8, interleaved: false),
              AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 4800) != nil else {
            throw XCTSkip("Skipping: 8-channel PCM buffers not supported on this environment")
        }
        let proc = AudioProcessor()
        let processStereo = makeSineBuffer(freq: 440, channels: 2)
        let input3 = makeSineBuffer(freq: 1000, channels: 1)
        let input5 = makeSineBuffer(freq: 2000, channels: 1)
        let out = proc.combine(processAudio: processStereo, inputAudioByChannel: [3: input3, 5: input5], totalChannels: 8)
        XCTAssertNotNil(out)
        let outBuf = out!
        XCTAssertEqual(outBuf.format.channelCount, 8)
        XCTAssertEqual(outBuf.frameLength, processStereo.frameLength)
        guard let ch = outBuf.floatChannelData else { return XCTFail("no channels") }
        let n = Int(outBuf.frameLength)
        // ch1 and ch2 non-zero
        let sum1 = (0..<n).reduce(0.0) { $0 + Double(ch[0][$1]) }
        let sum2 = (0..<n).reduce(0.0) { $0 + Double(ch[1][$1]) }
        XCTAssertNotEqual(sum1, 0)
        XCTAssertNotEqual(sum2, 0)
        // ch3 non-zero, ch4 zero (unused), ch5 non-zero
        let sum3 = (0..<n).reduce(0.0) { $0 + Double(ch[2][$1]) }
        let sum4 = (0..<n).reduce(0.0) { $0 + Double(ch[3][$1]) }
        let sum5 = (0..<n).reduce(0.0) { $0 + Double(ch[4][$1]) }
        XCTAssertNotEqual(sum3, 0)
        XCTAssertEqual(sum4, 0)
        XCTAssertNotEqual(sum5, 0)
        // ch6-8 zero (unused)
        let sum6 = (0..<n).reduce(0.0) { $0 + Double(ch[5][$1]) }
        let sum7 = (0..<n).reduce(0.0) { $0 + Double(ch[6][$1]) }
        let sum8 = (0..<n).reduce(0.0) { $0 + Double(ch[7][$1]) }
        XCTAssertEqual(sum6, 0)
        XCTAssertEqual(sum7, 0)
        XCTAssertEqual(sum8, 0)
    }

    func testALACCompatiblePCMConversion() throws {
        let processor = AudioProcessor()
        let srcFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: 512)!
        buffer.frameLength = 512
        memset(buffer.floatChannelData![0], 0, Int(buffer.frameLength) * MemoryLayout<Float>.size)
        let cfg = ALACConfiguration(sampleRate: 48_000, channelCount: 1, bitDepth: 16, quality: .max)
        let converted = processor.alacCompatiblePCM(buffer: buffer, config: cfg)
        XCTAssertNotNil(converted)
        XCTAssertEqual(converted?.format.commonFormat, .pcmFormatInt16)
        XCTAssertTrue(converted?.format.isInterleaved == true)
    }

    func testRecommendedALACBufferFrames() {
        let processor = AudioProcessor()
        let frames = processor.recommendedALACBufferFrames()
        XCTAssertEqual(frames, 4096)
    }
}
