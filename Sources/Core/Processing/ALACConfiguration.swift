import Foundation
import AVFoundation

public struct ALACConfiguration: Equatable {
    public let sampleRate: Double
    public let channelCount: AVAudioChannelCount
    public let bitDepth: Int
    public let quality: AVAudioQuality

    public init(sampleRate: Double = 48_000,
                channelCount: AVAudioChannelCount = 2,
                bitDepth: Int = 16,
                quality: AVAudioQuality = .max) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitDepth = bitDepth
        self.quality = quality
    }
}

public enum ALACValidationError: LocalizedError, Equatable {
    case unsupportedChannelCount(AVAudioChannelCount)
    case unsupportedSampleRate(Double)
    case unsupportedBitDepth(Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedChannelCount(let c):
            return "ALAC supports up to 8 channels. Requested: \(c)."
        case .unsupportedSampleRate(let sr):
            return "Unsupported ALAC sample rate: \(sr)."
        case .unsupportedBitDepth(let bd):
            return "Unsupported ALAC bit depth: \(bd)."
        }
    }
}

public enum ALACConfigurator {
    /// Validate configuration against expected ALAC constraints
    @discardableResult
    public static func validate(_ config: ALACConfiguration) throws -> ALACConfiguration {
        // Channels: 1...8
        guard config.channelCount >= 1 && config.channelCount <= 8 else {
            throw ALACValidationError.unsupportedChannelCount(config.channelCount)
        }
        // Sample rate: common valid range 8k...192k
        guard config.sampleRate >= 8_000 && config.sampleRate <= 192_000 else {
            throw ALACValidationError.unsupportedSampleRate(config.sampleRate)
        }
        // Bit depth: ALAC typically supports 16/20/24/32 hints. Constrain to 16 or 24 for now.
        guard config.bitDepth == 16 || config.bitDepth == 24 else {
            throw ALACValidationError.unsupportedBitDepth(config.bitDepth)
        }
        return config
    }

    /// Create AVAudioFile settings dictionary for ALAC (.m4a) given a validated configuration
    public static func alacSettings(for config: ALACConfiguration) throws -> [String: Any] {
        let cfg = try validate(config)
        var settings: [String: Any] = [:]
        settings[AVFormatIDKey] = kAudioFormatAppleLossless
        settings[AVNumberOfChannelsKey] = cfg.channelCount
        settings[AVSampleRateKey] = cfg.sampleRate
        settings[AVEncoderBitDepthHintKey] = cfg.bitDepth
        settings[AVEncoderAudioQualityKey] = cfg.quality.rawValue
        settings[AVSampleRateConverterAudioQualityKey] = cfg.quality.rawValue
        return settings
    }

    /// Attempt to create an AVAudioFormat from ALAC settings, if supported by the platform.
    /// Falls back to nil if AVAudioFormat cannot be constructed purely from settings.
    public static func alacFormat(for config: ALACConfiguration) -> AVAudioFormat? {
        do {
            let settings = try alacSettings(for: config)
            return AVAudioFormat(settings: settings)
        } catch {
            return nil
        }
    }

    /// Create a PCM client format suitable for feeding an ALAC encoder. Uses interleaved Int16.
    public static func pcmClientFormat(for config: ALACConfiguration) throws -> AVAudioFormat {
        let cfg = try validate(config)
        // Interleaved Int16 client format
        return AVAudioFormat(commonFormat: .pcmFormatInt16,
                             sampleRate: cfg.sampleRate,
                             channels: cfg.channelCount,
                             interleaved: true)!
    }
}
