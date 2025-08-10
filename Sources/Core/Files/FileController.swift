import Foundation
import AVFoundation

public final class FileController: FileControllerProtocol {
    public init() {}

    public func createOutputDirectory(_ path: String) throws {
        let url = expandTilde(in: path)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw AudioRecorderError.fileSystemError(error.localizedDescription)
        }
    }

    public func generateTimestampedFilename(extension ext: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.string(from: Date()) + "." + ext
    }

    public func writeAudioData(_ data: Data, to directory: String) throws -> URL {
        let dirURL = expandTilde(in: directory)
        let fileURL = dirURL.appendingPathComponent(generateTimestampedFilename(extension: "caf"))
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            // Fallback to default directory
            let fallbackDir = defaultOutputDirectory()
            do {
                try FileManager.default.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
                let fallbackURL = fallbackDir.appendingPathComponent(generateTimestampedFilename(extension: "caf"))
                try data.write(to: fallbackURL, options: .atomic)
                return fallbackURL
            } catch {
                throw AudioRecorderError.fileSystemError(error.localizedDescription)
            }
        }
    }

    public func writeMultiChannelAudioData(_ data: Data, to directory: String) throws -> URL {
        // Reuse the same filename generation; content is multi-channel audio data
        return try writeAudioData(data, to: directory)
    }

    public func writeChannelMappingLog(_ mappingJSON: Data, to directory: String, baseFilename: String) throws -> URL {
        let dirURL = expandTilde(in: directory)
        let jsonName: String
        if baseFilename.lowercased().hasSuffix(".wav") || baseFilename.lowercased().hasSuffix(".caf") || baseFilename.lowercased().hasSuffix(".m4a") {
            jsonName = String(baseFilename.dropLast(4)) + "-channels.json"
        } else {
            jsonName = baseFilename + "-channels.json"
        }
        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            let fileURL = dirURL.appendingPathComponent(jsonName)
            try mappingJSON.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            throw AudioRecorderError.fileSystemError(error.localizedDescription)
        }
    }

    public func writeWAVBuffer(_ buffer: AVAudioPCMBuffer, to directory: String, bitDepth: Int) throws -> URL {
        let dirURL = expandTilde(in: directory)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let fileURL = dirURL.appendingPathComponent(generateTimestampedFilename(extension: "wav"))

        // Build settings enforcing linear PCM with specified bit depth
        var settings: [String: Any] = [:]
        settings[AVFormatIDKey] = kAudioFormatLinearPCM
        settings[AVSampleRateKey] = buffer.format.sampleRate
        settings[AVNumberOfChannelsKey] = Int(buffer.format.channelCount)
        settings[AVLinearPCMBitDepthKey] = bitDepth
        settings[AVLinearPCMIsFloatKey] = (bitDepth == 32) // we will set false for 16-bit
        settings[AVLinearPCMIsBigEndianKey] = false
        settings[AVLinearPCMIsNonInterleaved] = true

        do {
            let outFile = try AVAudioFile(forWriting: fileURL, settings: settings)
            try outFile.write(from: buffer)
            return fileURL
        } catch {
            throw AudioRecorderError.fileSystemError(error.localizedDescription)
        }
    }

    public func writeCAFBuffer(_ buffer: AVAudioPCMBuffer, to directory: String) throws -> URL {
        let dirURL = expandTilde(in: directory)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let fileURL = dirURL.appendingPathComponent(generateTimestampedFilename(extension: "caf"))
        // Use buffer's format; AVAudioFile will choose CAF based on extension
        let settings = buffer.format.settings
        do {
            let outFile = try AVAudioFile(forWriting: fileURL, settings: settings)
            try outFile.write(from: buffer)
            return fileURL
        } catch {
            throw AudioRecorderError.fileSystemError(error.localizedDescription)
        }
    }

    // MARK: - ALAC (.m4a)
    public func createALACFile(in directory: String, config: ALACConfiguration) throws -> AVAudioFile {
        let dirURL = expandTilde(in: directory)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let fileURL = dirURL.appendingPathComponent(generateTimestampedFilename(extension: "m4a"))
        let settings = try ALACConfigurator.alacSettings(for: config)
        do {
            return try AVAudioFile(forWriting: fileURL, settings: settings)
        } catch {
            throw AudioRecorderError.fileSystemError(error.localizedDescription)
        }
    }

    public func writeALACBuffer(_ buffer: AVAudioPCMBuffer, to directory: String, config: ALACConfiguration) throws -> URL {
        do {
            let file = try createALACFile(in: directory, config: config)
            try file.write(from: buffer)
            return file.url
        } catch {
            // Fallback to uncompressed CAF if ALAC fails
            return try writeCAFBuffer(buffer, to: directory)
        }
    }

    public func writeALACMultiChannelBuffer(_ buffer: AVAudioPCMBuffer, to directory: String, config: ALACConfiguration) throws -> URL {
        return try writeALACBuffer(buffer, to: directory, config: config)
    }

    public func compressionStats(originalBytes: Int64, compressedFileURL: URL) -> (compressedBytes: Int64, ratio: Double) {
        let size = (try? compressedFileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let compressed = Int64(size)
        guard originalBytes > 0 else { return (compressed, 0.0) }
        let ratio = 1.0 - Double(compressed) / Double(originalBytes)
        return (compressed, ratio)
    }

    // MARK: - Helpers
    public func defaultOutputDirectory() -> URL {
        let docs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
        return docs.appendingPathComponent("audiocap", isDirectory: true)
    }

    private func expandTilde(in path: String) -> URL {
        if path.hasPrefix("~") {
            let expanded = NSString(string: path).expandingTildeInPath
            return URL(fileURLWithPath: expanded, isDirectory: true)
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
