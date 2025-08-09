import Foundation
import ArgumentParser

public struct AudioRecorderCLI: ParsableCommand {
    public static let configuration: CommandConfiguration = CommandConfiguration(
        commandName: "audiocap-recorder",
        abstract: "Record system audio filtered to processes matching a regex."
    )

    @Argument(help: "Regular expression to match process names and paths")
    public var processRegex: String

    @Option(name: .shortAndLong, help: "Output directory for recordings (default: ~/Documents/audiocap)")
    public var outputDirectory: String?

    @Flag(name: .shortAndLong, help: "Enable verbose logging")
    public var verbose: Bool = false

    public init() {}

    public func validate() throws {
        do {
            _ = try NSRegularExpression(pattern: processRegex)
        } catch {
            throw ValidationError("Invalid regex pattern: \(processRegex)")
        }
    }

    public mutating func run() throws {
        let permissionManager = PermissionManager()
        if !permissionManager.checkScreenRecordingPermission() {
            permissionManager.displayPermissionInstructions(for: .screenRecording)
            throw CleanExit.message("Screen recording permission is required. Please enable it and re-run.")
        }

        print("Recording configuration:")
        print("- Process regex: \(processRegex)")
        if let output = outputDirectory, !output.isEmpty {
            print("- Output directory: \(output)")
        } else {
            print("- Output directory: ~/Documents/audiocap/")
        }
        print("- Verbose: \(verbose)")

        // Further wiring will be implemented in later tasks
    }
}
