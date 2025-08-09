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

    public func generateTimestampedFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.string(from: Date()) + ".wav"
    }

    public func writeAudioData(_ data: Data, to directory: String) throws -> URL {
        let dirURL = expandTilde(in: directory)
        let fileURL = dirURL.appendingPathComponent(generateTimestampedFilename())
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            // Fallback to default directory
            let fallbackDir = defaultOutputDirectory()
            do {
                try FileManager.default.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
                let fallbackURL = fallbackDir.appendingPathComponent(generateTimestampedFilename())
                try data.write(to: fallbackURL, options: .atomic)
                return fallbackURL
            } catch {
                throw AudioRecorderError.fileSystemError(error.localizedDescription)
            }
        }
    }

    public func writeMultiChannelAudioData(_ data: Data, to directory: String) throws -> URL {
        // Reuse the same filename generation; content is multi-channel WAV data
        return try writeAudioData(data, to: directory)
    }

    public func writeChannelMappingLog(_ mappingJSON: Data, to directory: String, baseFilename: String) throws -> URL {
        let dirURL = expandTilde(in: directory)
        let jsonName: String
        if baseFilename.lowercased().hasSuffix(".wav") {
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
        let fileURL = dirURL.appendingPathComponent(generateTimestampedFilename())

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
