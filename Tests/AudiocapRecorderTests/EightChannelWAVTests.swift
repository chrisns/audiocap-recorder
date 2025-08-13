import XCTest
import AVFoundation
 import Core

final class EightChannelWAVTests: XCTestCase {
    private func makeSineBuffer(freq: Double, seconds: Double = 0.1, sampleRate: Double = 48_000, channels: AVAudioChannelCount = 1, amplitude: Float = 0.5) -> AVAudioPCMBuffer {
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
                    ch[c][i] = amplitude * Float(sin(twoPi * freq * t))
                }
            }
        }
        return buffer
    }

    func testWriteEightChannelCAFReadable() throws {
        // Skip if environment cannot create 8-channel buffers
        guard let fmt8 = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 8, interleaved: false),
              AVAudioPCMBuffer(pcmFormat: fmt8, frameCapacity: 4800) != nil else {
            throw XCTSkip("Skipping: 8-channel buffers not supported in this environment")
        }

        let processor = AudioProcessor()
        // Create process stereo and two input monos; leave others silent
        let processStereo = makeSineBuffer(freq: 440, seconds: 0.1, channels: 2)
        let input3 = makeSineBuffer(freq: 1000, seconds: 0.1, channels: 1)
        let input5 = makeSineBuffer(freq: 2000, seconds: 0.1, channels: 1)
        guard let eightFloat = processor.combine(processAudio: processStereo, inputAudioByChannel: [3: input3, 5: input5], totalChannels: 8) else {
            return XCTFail("Failed to combine to 8 channels")
        }

        let fc = FileController()
        let tempDir = NSTemporaryDirectory().appending("audiocap-tests-") + UUID().uuidString
        try fc.createOutputDirectory(tempDir)
        let url = try fc.writeCAFBuffer(eightFloat, to: tempDir)

        // Verify file readable and has 8 channels and 48kHz
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.fileFormat.channelCount, 8)
        XCTAssertEqual(file.fileFormat.sampleRate, 48_000)

        // Read small buffer and validate silent channels (4,6,7,8)
        let frames: AVAudioFrameCount = 1024
        let readFmt = file.processingFormat
        let buf = AVAudioPCMBuffer(pcmFormat: readFmt, frameCapacity: frames)!
        try file.read(into: buf, frameCount: frames)
        guard let ch = buf.floatChannelData else { return XCTFail("No channel data") }
        let n = Int(buf.frameLength)
        func sumAbs(_ c: Int) -> Float {
            var total: Float = 0
            for i in 0..<n { total += abs(ch[c][i]) }
            return total
        }
        XCTAssertGreaterThan(sumAbs(0), 0)
        XCTAssertGreaterThan(sumAbs(1), 0)
        XCTAssertGreaterThan(sumAbs(2), 0) // channel 3 has input
        XCTAssertEqual(sumAbs(3), 0, accuracy: 1e-5)
        XCTAssertGreaterThan(sumAbs(4), 0) // channel 5 has input
        XCTAssertEqual(sumAbs(5), 0, accuracy: 1e-5)
        XCTAssertEqual(sumAbs(6), 0, accuracy: 1e-5)
        XCTAssertEqual(sumAbs(7), 0, accuracy: 1e-5)
    }
}
