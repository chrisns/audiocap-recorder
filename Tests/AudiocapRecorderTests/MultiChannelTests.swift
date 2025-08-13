import XCTest
import AVFoundation
 import Core
final class MultiChannelTests: XCTestCase {
    func testChannelMappingJSONRoundtrip() throws {
        let fc = FileController()
        let tempDir = NSTemporaryDirectory().appending("audiocap-tests-") + UUID().uuidString
        try fc.createOutputDirectory(tempDir)
        let base = "2025-01-01-00-00-00.caf"
        let mapping: [String: Any] = [
            "sessionId": UUID().uuidString,
            "channels": [
                "1": "process",
                "2": "process",
                "3": "Mic 1"
            ]
        ]
        let json = try JSONSerialization.data(withJSONObject: mapping, options: [])
        let url = try fc.writeChannelMappingLog(json, to: tempDir, baseFilename: base)
        let loaded = try Data(contentsOf: url)
        let obj = try JSONSerialization.jsonObject(with: loaded, options: [])
        XCTAssertNotNil(obj as? [String: Any])
    }

    func testCombineEightChannelsPerformance() throws {
        // Skip if environment cannot create 8-channel buffers
        guard let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 8, interleaved: false),
              AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 48_000) != nil else {
            throw XCTSkip("Skipping: 8-channel buffers not supported in this environment")
        }
        let proc = AudioProcessor()
        let frames = AVAudioFrameCount(48_000)
        let stereo = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let processBuf = AVAudioPCMBuffer(pcmFormat: stereo, frameCapacity: frames)!
        processBuf.frameLength = frames
        if let ch = processBuf.floatChannelData { memset(ch[0], 0, Int(frames) * MemoryLayout<Float>.size); memset(ch[1], 0, Int(frames) * MemoryLayout<Float>.size) }
        var inputs: [Int: AVAudioPCMBuffer] = [:]
        for channel in 3...8 {
            let mono = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
            let buf = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: frames)!
            buf.frameLength = frames
            if let ch = buf.floatChannelData { memset(ch[0], 0, Int(frames) * MemoryLayout<Float>.size) }
            inputs[channel] = buf
        }
        measure {
            _ = proc.combine(processAudio: processBuf, inputAudioByChannel: inputs, totalChannels: 8)
        }
    }

    func testHotSwapPerformance() {
        let manager = InputDeviceManager()
        var devices: [AudioInputDevice] = []
        for i in 0..<6 {
            devices.append(AudioInputDevice(uid: "uid_\(i)", name: "Mic \(i)", channelCount: 1, sampleRate: 48_000))
        }
        measure {
            _ = manager.assignChannels(for: devices)
        }
    }
}
