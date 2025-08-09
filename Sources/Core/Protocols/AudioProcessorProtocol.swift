import Foundation
import AVFoundation

public protocol AudioProcessorProtocol {
    func processAudioBuffer(_ sampleBuffer: CMSampleBuffer, from processes: [RecorderProcessInfo]) -> AVAudioPCMBuffer?
    func mixAudioStreams(_ streams: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer?
    func convertToWAV(_ buffer: AVAudioPCMBuffer) -> Data
    func combine(processAudio: AVAudioPCMBuffer, inputAudioByChannel: [Int: AVAudioPCMBuffer], totalChannels: Int) -> AVAudioPCMBuffer?
    func convert(buffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) -> AVAudioPCMBuffer
}
