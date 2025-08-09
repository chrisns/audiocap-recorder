import Foundation
import AVFoundation

public protocol AudioProcessorProtocol {
    func processAudioBuffer(_ sampleBuffer: CMSampleBuffer, from processes: [RecorderProcessInfo]) -> AVAudioPCMBuffer?
    func mixAudioStreams(_ streams: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer?
    func convertToWAV(_ buffer: AVAudioPCMBuffer) -> Data
}
