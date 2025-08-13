import XCTest
import AVFoundation
 import AudiocapRecorder
private final class StubEngine: CompressionEngineProtocol {
    var lastCreated: AVAudioFile?
    var lastProcessedFrames: AVAudioFrameCount = 0
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws -> Data? { lastProcessedFrames = buffer.frameLength; return nil }
    func createOutputFile(at url: URL, format: AVAudioFormat) throws -> AVAudioFile { let f = try AVAudioFile(forWriting: url, settings: format.settings); lastCreated = f; return f }
    func finalizeCompression() throws -> CompressionStatistics { return CompressionStatistics(sessionId: UUID(), format: .aac, startTime: Date(), endTime: Date(), duration: 0, originalSize: 0, compressedSize: 0, compressionRatio: 0, fileSizeReduction: 0, bitrate: 0, sampleRate: 0, channelCount: 0, enabledVBR: false, encodingTime: 0, averageEncodingSpeed: 0, cpuUsagePercent: 0, memoryUsageMB: 0, averageBitrate: nil, peakBitrate: nil) }
    func getCompressionProgress() -> CompressionProgress { .init(bytesProcessed: 0, estimatedTotalBytes: 0, compressionRatio: 0, encodingSpeedMBps: 0, timeRemaining: nil, cpuUsagePercent: 0, elapsedSeconds: 0) }
}

final class AudioProcessorCompressionTests: XCTestCase {
    func testProcessAndRouteSendsFrames() {
        let proc = AudioProcessor(sampleRate: 48000, channels: 1)
        let engine = StubEngine()
        proc.setCompressionEngine(engine)

        // Build a dummy mono buffer to route directly via routeToCompression
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 256)!
        buf.frameLength = 256
        proc.routeToCompression(buffer: buf, desiredFormat: nil)
        XCTAssertEqual(engine.lastProcessedFrames, 256)
    }
}
