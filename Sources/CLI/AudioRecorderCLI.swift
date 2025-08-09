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

    public func run() throws {
        let permissionManager = PermissionManager()
        if !permissionManager.checkScreenRecordingPermission() {
            permissionManager.displayPermissionInstructions(for: .screenRecording)
            throw CleanExit.message("Screen recording permission is required. Please enable it and re-run.")
        }

        let logger = Logger(verbose: verbose)
        let errorPresenter = ErrorPresenter()
        logger.info("Recording configuration:")
        logger.info("- Process regex: \(processRegex)")
        if let output = outputDirectory, !output.isEmpty {
            logger.info("- Output directory: \(output)")
        } else {
            logger.info("- Output directory: ~/Documents/audiocap/")
        }
        logger.info("- Verbose: \(verbose)")

        let processManager = ProcessManager()
        let processes: [RecorderProcessInfo]
        do {
            processes = try processManager.discoverProcesses(matching: processRegex)
        } catch let error as AudioRecorderError {
            logger.error(errorPresenter.present(error))
            throw CleanExit.message(error.localizedDescription)
        }

        if processes.isEmpty {
            let err = AudioRecorderError.processNotFound(processRegex)
            logger.error(errorPresenter.present(err))
            throw CleanExit.message(err.localizedDescription)
        }

        var capturer = AudioCapturer(permissionManager: permissionManager)
        capturer.setOutputDirectory(outputDirectory)

        let shutdown = ShutdownCoordinator(audioCapturer: capturer, fileController: FileController())
        let signalHandler = SignalHandler(signalNumber: SIGINT)
        let outDir = self.outputDirectory
        signalHandler.start {
            shutdown.performGracefulShutdown(finalData: nil, outputDirectory: outDir)
            Foundation.exit(0)
        }

        let processesCopy = processes
        let loggerCopy = logger
        let presenterCopy = errorPresenter
        Task { @MainActor in
            do {
                try await capturer.startCapture(for: processesCopy)
            } catch let error as AudioRecorderError {
                loggerCopy.error(presenterCopy.present(error))
                Foundation.exit(1)
            } catch {
                loggerCopy.error("Unexpected error: \(error.localizedDescription)")
                Foundation.exit(1)
            }
        }

        dispatchMain()
    }
}
