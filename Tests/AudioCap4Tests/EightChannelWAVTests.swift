import XCTest
import AVFoundation
@testable import AudioCap4

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

    private func parseBitsPerSample(fromWAVAt url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        guard data.count >= 44 else { throw NSError(domain: "wav", code: -1) }
        // Search for "fmt " chunk
        let bytes = [UInt8](data)
        var fmtIndex: Int? = nil
        var i = 12 // skip RIFF header (12 bytes)
        while i + 8 <= bytes.count {
            // chunk id 4 bytes
            if i + 8 > bytes.count { break }
            let id0 = bytes[i]
            let id1 = bytes[i+1]
            let id2 = bytes[i+2]
            let id3 = bytes[i+3]
            let size = Int(UInt32(bytes[i+4]) | (UInt32(bytes[i+5]) << 8) | (UInt32(bytes[i+6]) << 16) | (UInt32(bytes[i+7]) << 24))
            if id0 == 0x66 && id1 == 0x6d && id2 == 0x74 && id3 == 0x20 { // 'f''m''t'' '
                fmtIndex = i
                break
            }
            i += 8 + size
        }
        guard let idx = fmtIndex else { throw NSError(domain: "wav", code: -2) }
        let bitsOffset = idx + 20 // within fmt, bits-per-sample at offset 20 of fmt body for PCM
        guard bitsOffset + 2 <= bytes.count else { throw NSError(domain: "wav", code: -3) }
        let bitsLE = Int(UInt16(bytes[bitsOffset]) | (UInt16(bytes[bitsOffset+1]) << 8))
        return bitsLE
    }

    func testWriteEightChannelWAVWith16BitHeaders() throws {
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
        // Convert to 16-bit int non-interleaved (file writing will interleave as needed)
        let int16Fmt = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48_000, channels: 8, interleaved: false)!
        let eightInt16 = processor.convert(buffer: eightFloat, to: int16Fmt)

        let fc = FileController()
        let tempDir = NSTemporaryDirectory().appending("audiocap-tests-") + UUID().uuidString
        try fc.createOutputDirectory(tempDir)
        let url = try fc.writeWAVBuffer(eightInt16, to: tempDir, bitDepth: 16)

        // Verify file readable and has 8 channels and 48kHz
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.fileFormat.channelCount, 8)
        XCTAssertEqual(file.fileFormat.sampleRate, 48_000)
        // Verify header reports 16-bit
        let bits = try parseBitsPerSample(fromWAVAt: url)
        XCTAssertEqual(bits, 16)

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
