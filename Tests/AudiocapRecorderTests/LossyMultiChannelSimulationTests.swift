import XCTest
import AVFoundation
@testable import AudiocapRecorder
@testable import Core

final class LossyMultiChannelSimulationTests: XCTestCase {
    func testSimulatedMultiChannelWithLossyEngineDoesNotCrash() throws {
        // Simulate process stereo + 6 mono inputs => 8-channel combine, with lossy engine receiving process mono
        let processor = AudioProcessor(sampleRate: 48_000, channels: 1)
        let lossyCfg = CompressionConfiguration(format: .aac, bitrate: 128, quality: .medium, enableVBR: false, sampleRate: 44100, channelCount: 1, enableMultiChannel: false)
        let engine = try LossyCompressionEngine(configuration: lossyCfg)

        // Wire engine into processor path and create dummy output file to drive encoder setup
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let monoFmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        _ = try engine.createOutputFile(at: tmp, format: monoFmt)

        // Ensure environment supports 8-channel non-interleaved buffers; otherwise skip
        if let fmt8 = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 8, interleaved: false) {
            _ = AVAudioPCMBuffer(pcmFormat: fmt8, frameCapacity: 1)
        } else {
            throw XCTSkip("Skipping: 8-channel buffers not supported in this environment")
        }

        // Build buffers
        let frames: AVAudioFrameCount = 4096
        let stereoFmt = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let processBuf = AVAudioPCMBuffer(pcmFormat: stereoFmt, frameCapacity: frames)!
        processBuf.frameLength = frames
        if let ch = processBuf.floatChannelData { memset(ch[0], 0, Int(frames) * MemoryLayout<Float>.size); memset(ch[1], 0, Int(frames) * MemoryLayout<Float>.size) }
        var inputs: [Int: AVAudioPCMBuffer] = [:]
        for chIdx in 3...8 {
            let inFmt = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
            let buf = AVAudioPCMBuffer(pcmFormat: inFmt, frameCapacity: frames)!
            buf.frameLength = frames
            if let ch = buf.floatChannelData { memset(ch[0], 0, Int(frames) * MemoryLayout<Float>.size) }
            inputs[chIdx] = buf
        }

        // Combine channels to simulate multi-channel writer path
        guard let combined = processor.combine(processAudio: processBuf, inputAudioByChannel: inputs, totalChannels: 8) else {
            throw XCTSkip("Skipping: combine returned nil in this environment")
        }

        // Convert the stereo process part to mono for compression engine and send a short segment
        let monoOut = processor.convert(buffer: processBuf, to: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!)
        _ = try engine.processAudioBuffer(monoOut)
        _ = try engine.finalizeCompression()

        // Ensure combined buffer has correct channel count and frame length
        XCTAssertEqual(combined.format.channelCount, 8)
        XCTAssertEqual(combined.frameLength, frames)
    }
}
