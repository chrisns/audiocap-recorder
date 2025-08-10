import Foundation
import AVFoundation

/// Describes a generic audio encoder used by a compression engine
public protocol AudioEncoderProtocol {
    func initialize(configuration: LossyCompressionConfiguration) throws
    func encode(buffer: AVAudioPCMBuffer) throws -> Data
    func finalize() throws -> CompressionStatistics
    func createAudioFile(at url: URL, format: AVAudioFormat) throws -> AVAudioFile
    func getEstimatedFileSize(for duration: TimeInterval) -> Int64
    func getCompressionRatio() -> Double
    func supportsMultiChannel() -> Bool
    func getMaximumChannelCount() -> UInt32
}

/// Provides a common facade for compression engines
public protocol CompressionEngineProtocol {
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws -> Data?
    func createOutputFile(at url: URL, format: AVAudioFormat) throws -> AVAudioFile
    func finalizeCompression() throws -> CompressionStatistics
    func getCompressionProgress() -> CompressionProgress
}

/// Lightweight progress snapshot for realtime reporting
public struct CompressionProgress {
    let bytesProcessed: Int64
    let estimatedTotalBytes: Int64
    let compressionRatio: Double
    let encodingSpeedMBps: Double
    let timeRemaining: TimeInterval?
    let cpuUsagePercent: Double
    let elapsedSeconds: TimeInterval
}
