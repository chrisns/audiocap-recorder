import Foundation
import AVFoundation

public final class CompressionFallbackManager {
    public init() {}

    // Attempt to recover from an encoding failure by falling back to uncompressed CAF output
    // Returns the URL of the fallback file
    @discardableResult
    public func fallbackToUncompressedCAF(
        originalBuffer: AVAudioPCMBuffer,
        directory: String?,
        fileController: FileControllerProtocol = FileController()
    ) throws -> URL {
        let outDir = directory ?? FileController().defaultOutputDirectory().path
        return try fileController.writeCAFBuffer(originalBuffer, to: outDir)
    }

    // Validate basic system compatibility for the desired compression format and provide errors early
    public func validateCompatibility(for config: CompressionConfiguration) throws {
        // MP3: enforce stereo limit and no VBR at this stage as a compatibility check
        if config.format == .mp3 {
            if config.channelCount > 2 {
                throw AudioRecorderError.compressionConfigurationInvalid("MP3 supports mono or stereo only")
            }
            if config.enableVBR {
                throw AudioRecorderError.compressionConfigurationInvalid("MP3 VBR is not supported")
            }
        }
        // Lossy bitrate range check
        if config.format.isLossy {
            if config.bitrate < 64 || config.bitrate > 320 {
                throw AudioRecorderError.compressionConfigurationInvalid("Bitrate must be 64-320 kbps")
            }
            let allowed: Set<Double> = [22050, 44100, 48000]
            if !allowed.contains(config.sampleRate) {
                throw AudioRecorderError.compressionConfigurationInvalid("Sample rate must be one of 22050, 44100, 48000 Hz")
            }
        }
    }

    // Attempt to correct an invalid lossy configuration by clamping to supported values
    public func sanitizeConfiguration(_ config: CompressionConfiguration) -> CompressionConfiguration {
        var cfg = config
        if cfg.format.isLossy {
            // Clamp bitrate
            if cfg.bitrate < 64 { cfg.bitrate = 64 }
            if cfg.bitrate > 320 { cfg.bitrate = 320 }
            // Snap sample rate to nearest allowed
            let allowed: [Double] = [22050, 44100, 48000]
            if !allowed.contains(cfg.sampleRate) {
                let nearest = allowed.min(by: { abs($0 - cfg.sampleRate) < abs($1 - cfg.sampleRate) }) ?? 48000
                cfg.sampleRate = nearest
            }
        }
        // MP3: reduce channels and disable VBR if necessary
        if cfg.format == .mp3 {
            if cfg.channelCount > 2 { cfg.channelCount = 2 }
            if cfg.enableVBR { cfg.enableVBR = false }
        }
        return cfg
    }

    // Produce a user-facing guidance string for a given compression error
    public func recoverySuggestion(for error: AudioRecorderError) -> String {
        switch error {
        case .compressionNotSupported:
            return "This system may not support the requested encoder. Try --aac or remove compression flags to record uncompressed CAF."
        case .compressionConfigurationInvalid:
            return "Adjust bitrate (64-320), sample rate (22050/44100/48000), and for MP3 use mono or stereo without --vbr."
        case .compressionEncodingFailed:
            return "The recorder will fall back to uncompressed CAF automatically. You can also retry with a lower bitrate or switch formats."
        default:
            return ""
        }
    }
}
