import Foundation
import ArgumentParser
import AVFoundation

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

    @Flag(name: .shortAndLong, help: "Capture all audio input devices in addition to process audio")
    public var captureInputs: Bool = false

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

        if captureInputs {
            if !permissionManager.checkMicrophonePermission() {
                permissionManager.displayPermissionInstructions(for: .microphone)
                throw CleanExit.message("Microphone permission is required when using --capture-inputs. Please enable it and re-run.")
            }
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
        logger.info("- Capture inputs: \(captureInputs)")

        let processManager = ProcessManager()
        let processes: [RecorderProcessInfo]
        do {
            processes = try processManager.discoverProcesses(matching: processRegex)
        } catch let error as AudioRecorderError {
            logger.error(errorPresenter.present(error))
            throw CleanExit.message(error.localizedDescription)
        }

        if processes.isEmpty {
            let skip = ProcessInfo.processInfo.environment["AUDIOCAP_SKIP_PROCESS_CHECK"] == "1"
            if !skip {
                let err = AudioRecorderError.processNotFound(processRegex)
                logger.error(errorPresenter.present(err))
                throw CleanExit.message(err.localizedDescription)
            } else {
                logger.warn("No matching processes found. Proceeding due to AUDIOCAP_SKIP_PROCESS_CHECK=1.")
            }
        }

        // Optional input device manager lifecycle
        var inputManager: InputDeviceManager? = nil
        if captureInputs {
            let manager = InputDeviceManager()
            let reporter = InputStatusReporter(logger: logger)
            manager.delegate = reporter
            let devices = manager.enumerateInputDevices()
            if devices.isEmpty {
                logger.warn("No input devices detected. Proceeding with process audio only.")
            } else {
                let mapping = manager.currentChannelAssignments().sorted(by: { $0.key < $1.key })
                logger.info("Input channel assignments:")
                for (channel, device) in mapping {
                    logger.info("- Channel \(channel): \(device.name) [uid=\(device.uid)]")
                }
            }
            manager.startMonitoring()
            manager.startCapturing()
            inputManager = manager
        }

        let capturer = AudioCapturer(permissionManager: permissionManager)
        capturer.setOutputDirectory(outputDirectory)

        let shutdown = ShutdownCoordinator(audioCapturer: capturer, fileController: FileController())
        let signalHandler = SignalHandler(signalNumber: SIGINT)
        let outDir = self.outputDirectory
        signalHandler.start {
            // Stop input devices first
            if let im = inputManager {
                im.stopCapturing()
                im.stopMonitoring()
            }
            shutdown.performGracefulShutdown(finalData: nil, outputDirectory: outDir)
            Foundation.exit(0)
        }

        let processesCopy = processes
        let loggerCopy = logger
        let presenterCopy = errorPresenter
        Task {
            do {
                try await capturer.startCapture(for: processesCopy)
            } catch let error as AudioRecorderError {
                loggerCopy.error(presenterCopy.present(error))
                // Stop input devices on error
                if let im = inputManager {
                    im.stopCapturing()
                    im.stopMonitoring()
                }
                Foundation.exit(1)
            } catch {
                loggerCopy.error("Unexpected error: \(error.localizedDescription)")
                if let im = inputManager {
                    im.stopCapturing()
                    im.stopMonitoring()
                }
                Foundation.exit(1)
            }
        }

        dispatchMain()
    }
}

// MARK: - Input status reporter
final class InputStatusReporter: InputDeviceManagerDelegate {
    private let logger: Logger
    init(logger: Logger) { self.logger = logger }

    func deviceConnected(_ device: AudioInputDevice, assignedToChannel channel: Int) {
        logger.info("Input device connected: \(device.name) -> channel \(channel)")
    }

    func deviceDisconnected(_ device: AudioInputDevice, fromChannel channel: Int) {
        logger.info("Input device disconnected: \(device.name) from channel \(channel)")
    }

    func audioDataReceived(from device: AudioInputDevice, buffer: AVAudioPCMBuffer) {
        // For Task 22, we only report status. Future tasks will combine into multi-channel output.
    }
}
