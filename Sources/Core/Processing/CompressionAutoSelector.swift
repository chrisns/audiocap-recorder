import Foundation

public final class CompressionAutoSelector {
    private let advisor = CompressionAdvisor()

    public init() {}

    public struct AutoSelectOptions {
        public let content: ContentType
        public let durationSeconds: TimeInterval
        public let channels: UInt32
        public let needMaxCompatibility: Bool
        public init(content: ContentType, durationSeconds: TimeInterval, channels: UInt32, needMaxCompatibility: Bool) {
            self.content = content
            self.durationSeconds = durationSeconds
            self.channels = channels
            self.needMaxCompatibility = needMaxCompatibility
        }
    }

    public func selectConfiguration(options: AutoSelectOptions) -> CompressionConfiguration {
        let advice = advisor.recommend(content: options.content, durationSeconds: options.durationSeconds, channels: options.channels, needMaxCompatibility: options.needMaxCompatibility)
        let format: CompressionConfiguration.CompressionFormat = advice.format
        let bitrate = advice.recommendedBitrateKbps
        let vbr = (format == .aac)
        let sampleRate: Double = advice.sampleRate
        return CompressionConfiguration(format: format, bitrate: bitrate, quality: nil, enableVBR: vbr, sampleRate: sampleRate, channelCount: options.channels, enableMultiChannel: options.channels > 2)
    }
}
