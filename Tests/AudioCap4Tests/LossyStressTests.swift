import XCTest
import AVFoundation
@testable import AudioCap4

final class LossyStressTests: XCTestCase {
    func testAACStressLargeBuffers() throws {
        let cfg = CompressionConfiguration(format: .aac, bitrate: 192, quality: .high, enableVBR: false, sampleRate: 44100, channelCount: 2, enableMultiChannel: false)
        let engine = try LossyCompressionEngine(configuration: cfg)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        _ = try engine.createOutputFile(at: url, format: fmt)

        let iterations = 150
        let cap: AVAudioFrameCount = 16384
        for _ in 0..<iterations {
            let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: cap)!
            buf.frameLength = cap
            if let ch = buf.floatChannelData {
                let count = Int(cap)
                for i in 0..<count { ch[0][i] = Float.random(in: -1...1) }
                for i in 0..<count { ch[1][i] = Float.random(in: -1...1) }
            }
            _ = try engine.processAudioBuffer(buf)
        }
        let stats = try engine.finalizeCompression()
        XCTAssertGreaterThan(stats.compressedSize, 0)
    }

    func testMP3StressSkipsIfUnsupported() throws {
        let cfg = CompressionConfiguration(format: .mp3, bitrate: 192, quality: .high, enableVBR: false, sampleRate: 44100, channelCount: 2, enableMultiChannel: false)
        let engine = try LossyCompressionEngine(configuration: cfg)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp3")
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        do {
            _ = try engine.createOutputFile(at: url, format: fmt)
        } catch AudioRecorderError.compressionNotSupported {
            return
        }
        let cap: AVAudioFrameCount = 8192
        for _ in 0..<50 {
            let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: cap)!
            buf.frameLength = cap
            if let ch = buf.floatChannelData {
                let count = Int(cap)
                for i in 0..<count { ch[0][i] = Float.random(in: -0.5...0.5) }
                for i in 0..<count { ch[1][i] = Float.random(in: -0.5...0.5) }
            }
            _ = try engine.processAudioBuffer(buf)
        }
        let stats = try engine.finalizeCompression()
        XCTAssertGreaterThan(stats.compressedSize, 0)
    }

    func testRandomizedMultiChannelCombineOverVariousFrameLengths() throws {
        // Skip if environment does not support 8-channel buffers
        guard let fmt8 = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 8, interleaved: false), AVAudioPCMBuffer(pcmFormat: fmt8, frameCapacity: 1) != nil else {
            throw XCTSkip("Skipping: 8-channel buffers not supported in this environment")
        }
        let proc = AudioProcessor(sampleRate: 48_000, channels: 1)
        let stereoFmt = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let candidates: [AVAudioFrameCount] = [256, 512, 1024, 2048, 4096]
        for _ in 0..<50 {
            let frames = candidates.randomElement()!
            guard let processBuf = AVAudioPCMBuffer(pcmFormat: stereoFmt, frameCapacity: frames) else { continue }
            processBuf.frameLength = frames
            if let ch = processBuf.floatChannelData {
                let n = Int(frames)
                for i in 0..<n { ch[0][i] = Float.random(in: -1...1) }
                for i in 0..<n { ch[1][i] = Float.random(in: -1...1) }
            }
            var inputs: [Int: AVAudioPCMBuffer] = [:]
            for chIdx in 3...8 {
                let monoFmt = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
                let buf = AVAudioPCMBuffer(pcmFormat: monoFmt, frameCapacity: frames)!
                buf.frameLength = frames
                if let ch = buf.floatChannelData {
                    let n = Int(frames)
                    for i in 0..<n { ch[0][i] = Float.random(in: -1...1) }
                }
                inputs[chIdx] = buf
            }
            let combined = proc.combine(processAudio: processBuf, inputAudioByChannel: inputs, totalChannels: 8)
            XCTAssertNotNil(combined)
            if let out = combined {
                XCTAssertEqual(out.format.channelCount, 8)
                XCTAssertEqual(out.frameLength, frames)
            }
        }
    }
}
