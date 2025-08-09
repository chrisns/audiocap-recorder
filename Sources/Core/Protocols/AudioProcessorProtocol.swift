import Foundation

public protocol AudioProcessorProtocol {
    func processSampleBuffer(_ sampleBuffer: Any, from processes: [RecorderProcessInfo]) -> Any?
    func mixAudioStreams(_ streams: [Any]) -> Any?
    func convertToWAV(_ buffer: Any) -> Data
}
