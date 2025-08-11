import Foundation

public struct CompressionChainStep: Equatable {
    public let format: CompressionConfiguration.CompressionFormat
    public let bitrateKbps: UInt32
    public let sampleRate: Double
    public let channels: UInt32
    public init(format: CompressionConfiguration.CompressionFormat, bitrateKbps: UInt32, sampleRate: Double, channels: UInt32) {
        self.format = format
        self.bitrateKbps = bitrateKbps
        self.sampleRate = sampleRate
        self.channels = channels
    }
}

public final class CompressionChaining {
    private let migrator = CompressionMigration()

    public init() {}

    public func runChain(inputURL: URL, steps: [CompressionChainStep], outputDirectory: URL, dryRun: Bool = true) throws -> [URL] {
        var inURL = inputURL
        var outputs: [URL] = []
        for (idx, step) in steps.enumerated() {
            let ext: String
            switch step.format {
            case .aac, .alac: ext = "m4a"
            case .mp3: ext = "mp3"
            case .uncompressed: ext = "caf"
            }
            let out = outputDirectory.appendingPathComponent("chain-step-\(idx).\(ext)")
            let url = try migrator.transcode(inputURL: inURL, to: step.format, bitrateKbps: step.bitrateKbps, sampleRate: step.sampleRate, channels: step.channels, outputURL: out, dryRun: dryRun)
            outputs.append(url)
            inURL = url
        }
        return outputs
    }
}
