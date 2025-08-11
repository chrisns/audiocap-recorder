import Foundation
@preconcurrency import AVFoundation

public struct ValidationIssue: Equatable {
    public let message: String
}

public struct ValidationReport: Equatable {
    public let isValid: Bool
    public let issues: [ValidationIssue]
}

public final class CompressionValidator {
    public init() {}

    public func validateFileIntegrity(url: URL, format: CompressionConfiguration.CompressionFormat) -> ValidationReport {
        var issues: [ValidationIssue] = []
        if !FileManager.default.fileExists(atPath: url.path) {
            issues.append(.init(message: "File does not exist: \(url.path)"))
        }
        let expectedExt = format.fileExtension.lowercased()
        if url.pathExtension.lowercased() != expectedExt {
            issues.append(.init(message: "Unexpected file extension: .\(url.pathExtension). Expected .\(expectedExt)"))
        }
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size == 0 {
            issues.append(.init(message: "File is empty (0 bytes)"))
        }
        // Attempt readability for AAC only (MP3 readability may not be supported on all systems)
        if format == .aac {
            do { _ = try AVAudioFile(forReading: url) } catch {
                issues.append(.init(message: "AVAudioFile failed to open AAC: \(error.localizedDescription)"))
            }
        }
        return ValidationReport(isValid: issues.isEmpty, issues: issues)
    }

    public func validateMetadataConsistency(_ stats: CompressionStatistics) -> ValidationReport {
        var issues: [ValidationIssue] = []
        if stats.endTime < stats.startTime {
            issues.append(.init(message: "endTime earlier than startTime"))
        }
        if stats.duration < 0 {
            issues.append(.init(message: "Negative duration"))
        }
        if stats.compressedSize < 0 {
            issues.append(.init(message: "Negative compressedSize"))
        }
        if stats.bitrate == 0 && (stats.format == .aac || stats.format == .mp3) {
            issues.append(.init(message: "Bitrate missing for lossy format"))
        }
        return ValidationReport(isValid: issues.isEmpty, issues: issues)
    }

    public func validateEfficiency(stats: CompressionStatistics, toleranceRatio: Double = 0.35) -> ValidationReport {
        // Compare compressed size vs expected from bitrate*duration using simple CBR estimate
        // For VBR, this is a rough check; allow larger tolerance
        var issues: [ValidationIssue] = []
        let expectedBytes = Int64((Double(stats.bitrate) * 1000.0 / 8.0) * stats.duration)
        if expectedBytes > 0 {
            let diff = abs(Double(stats.compressedSize) - Double(expectedBytes))
            let ratio = diff / Double(expectedBytes)
            if ratio > toleranceRatio {
                issues.append(.init(message: String(format: "Compressed size deviates from expected by %.0f%%", ratio * 100.0)))
            }
        }
        return ValidationReport(isValid: issues.isEmpty, issues: issues)
    }

    public func validateAverageBitrate(stats: CompressionStatistics) -> ValidationReport {
        guard stats.enabledVBR, let avg = stats.averageBitrate, stats.duration > 0 else {
            return ValidationReport(isValid: true, issues: [])
        }
        // Compute observed average kbps from size & duration
        let observedAvgKbps = UInt32((Double(stats.compressedSize) * 8.0 / stats.duration) / 1000.0)
        let diff = abs(Int64(observedAvgKbps) - Int64(avg))
        if diff > 64 { // allow generous tolerance
            return ValidationReport(isValid: false, issues: [.init(message: "VBR average bitrate deviates significantly from observed")])
        }
        return ValidationReport(isValid: true, issues: [])
    }
}
