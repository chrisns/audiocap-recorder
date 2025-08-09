import Foundation

public struct AudioConfiguration: Equatable {
    public let sampleRate: Int
    public let channelCount: Int
    public let bitDepth: Int
    public let maxDurationHours: Int
    public let bufferSize: Int

    public init(
        sampleRate: Int = 48_000,
        channelCount: Int = 2,
        bitDepth: Int = 16,
        maxDurationHours: Int = 12,
        bufferSize: Int = 4096
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitDepth = bitDepth
        self.maxDurationHours = maxDurationHours
        self.bufferSize = bufferSize
    }
}
