import Foundation

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
