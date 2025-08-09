import Foundation
import AVFoundation

let sampleRate = 48_000.0
let frequency = Double(ProcessInfo.processInfo.environment["SINE_FREQ_HZ"] ?? "1000") ?? 1000.0
let durationSec = Double(ProcessInfo.processInfo.environment["SINE_DURATION_SEC"] ?? "5") ?? 5.0

let engine = AVAudioEngine()
var phase: Double = 0
let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
    let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
    let frames = Int(frameCount)
    let thetaIncrement = 2.0 * Double.pi * frequency / sampleRate
    for buffer in abl {
        let ptr = buffer.mData!.bindMemory(to: Float.self, capacity: frames)
        var theta = phase
        for i in 0..<frames {
            ptr[i] = Float(sin(theta) * 0.25)
            theta += thetaIncrement
            if theta > 2.0 * Double.pi { theta -= 2.0 * Double.pi }
        }
        phase = theta
    }
    return noErr
}
let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
engine.attach(sourceNode)
engine.connect(sourceNode, to: engine.mainMixerNode, format: format)

do {
    try engine.start()
    RunLoop.main.run(until: Date().addingTimeInterval(durationSec))
    engine.stop()
} catch {
    fputs("SineWavePlayer error: \(error)\n", stderr)
    exit(1)
}
