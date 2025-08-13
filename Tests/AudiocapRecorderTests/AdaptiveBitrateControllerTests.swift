import XCTest
import AVFoundation
 import AudiocapRecorder
final class AdaptiveBitrateControllerTests: XCTestCase {
    private func makeBuffer(sineHz: Double?, noiseAmplitude: Float, frames: Int = 4096, sampleRate: Double = 48000, channels: Int = 2) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: AVAudioChannelCount(channels))!
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buf.frameLength = AVAudioFrameCount(frames)
        guard let ch = buf.floatChannelData else { return buf }
        for i in 0..<frames {
            let t = Double(i) / sampleRate
            let sine: Float = sineHz != nil ? sinf(2 * .pi * Float(sineHz! * t)) : 0
            let noise: Float = noiseAmplitude > 0 ? Float.random(in: -noiseAmplitude...noiseAmplitude) : 0
            let v = sine + noise
            for c in 0..<channels { ch[c][i] = v }
        }
        return buf
    }

    func testSuggestsHigherBitrateForLoudTonalContent() {
        let ctrl = AdaptiveBitrateController(sampleRate: 48000)
        let buf = makeBuffer(sineHz: 8000, noiseAmplitude: 0.02)
        let metrics = ctrl.analyze(buf)
        let kbps = ctrl.suggestBitrate(baseKbps: 128, metrics: metrics)
        XCTAssertGreaterThanOrEqual(kbps, 160)
    }

    func testSuggestsLowerBitrateForQuietNoisyContent() {
        let ctrl = AdaptiveBitrateController(sampleRate: 48000)
        let buf = makeBuffer(sineHz: nil, noiseAmplitude: 0.005)
        let metrics = ctrl.analyze(buf)
        let kbps = ctrl.suggestBitrate(baseKbps: 192, metrics: metrics)
        XCTAssertLessThanOrEqual(kbps, 128)
    }
}
