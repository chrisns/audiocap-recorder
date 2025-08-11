import Foundation
import ArgumentParser
import AVFoundation

public struct AudioRecorderCLI: ParsableCommand {
    public static let configuration: CommandConfiguration = CommandConfiguration(
        commandName: "audiocap-recorder",
        abstract: "Record system audio filtered to processes matching a regex. Supports uncompressed CAF, ALAC lossless (--alac), and lossy compression options (--aac/--mp3)."
    )

    @Argument(help: "Regular expression to match process names and paths")
    public var processRegex: String

    @Option(name: .shortAndLong, help: "Output directory for recordings (default: ~/Documents/audiocap)")
    public var outputDirectory: String?

    @Flag(name: .shortAndLong, help: "Enable verbose logging")
    public var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "Capture all audio input devices in addition to process audio")
    public var captureInputs: Bool = false

    @Flag(name: [.customShort("a"), .customLong("alac")], help: "Enable ALAC (Apple Lossless) compression for output files (.m4a)")
    public var enableALAC: Bool = false

    // Lossy compression options
    @Flag(name: [.customLong("aac")], help: "Enable AAC compression for output files (.m4a)")
    public var enableAAC: Bool = false

    @Flag(name: [.customLong("mp3")], help: "Enable MP3 compression for output files (.mp3)")
    public var enableMP3: Bool = false

    @Option(name: [.customLong("bitrate")], help: "Set bitrate for lossy compression in kbps (64-320)")
    public var bitrate: UInt32?

    @Option(name: [.customLong("quality")], help: "Set quality preset for lossy compression: low, medium, high, maximum")
    public var quality: CompressionQuality?

    @Flag(name: [.customLong("vbr")], help: "Enable Variable Bitrate (VBR) encoding (AAC only)")
    public var vbr: Bool = false

    @Option(name: [.customLong("sample-rate")], help: "Set sample rate for lossy compression (22050, 44100, 48000)")
    public var sampleRate: Double?

    public init() {}

    public func validate() throws {
        do {
            _ = try NSRegularExpression(pattern: processRegex)
        } catch {
            throw ValidationError("Invalid regex pattern: \(processRegex)")
        }
        try validateCompressionFlags()
    }

    private func validateCompressionFlags() throws {
        let compressionFlags = [enableALAC, enableAAC, enableMP3]
        let enabledCount = compressionFlags.filter { $0 }.count
        if enabledCount > 1 {
            throw ValidationError("Multiple compression modes selected. Please choose only one of --alac, --aac, or --mp3.")
        }

        if let bitrate = bitrate {
            guard bitrate >= 64 && bitrate <= 320 else {
                throw ValidationError("Bitrate must be between 64 and 320 kbps")
            }
            guard enableAAC || enableMP3 else {
                throw ValidationError("--bitrate requires a lossy compression format (--aac or --mp3)")
            }
        }

        if quality != nil {
            guard enableAAC || enableMP3 else {
                throw ValidationError("--quality requires a lossy compression format (--aac or --mp3)")
            }
        }

        if let _ = quality, let _ = bitrate {
            throw ValidationError("Specify either --quality or --bitrate, not both")
        }

        if vbr {
            guard enableAAC else {
                throw ValidationError("--vbr is only supported with --aac")
            }
        }

        if let rate = sampleRate {
            let allowed: Set<Double> = [22050, 44100, 48000]
            guard allowed.contains(rate) else {
                throw ValidationError("--sample-rate must be one of: 22050, 44100, 48000")
            }
            guard enableAAC || enableMP3 else {
                throw ValidationError("--sample-rate requires a lossy compression format (--aac or --mp3)")
            }
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
                // Request mic permission interactively and wait for response
                print("Requesting Microphone permission...")
                let sema = DispatchSemaphore(value: 0)
                var granted: Bool = false
                permissionManager.requestMicrophonePermission { ok in
                    granted = ok
                    sema.signal()
                }
                _ = sema.wait(timeout: .now() + 60)
                if !granted {
                    permissionManager.displayPermissionInstructions(for: .microphone)
                    throw CleanExit.message("Microphone permission is required when using --capture-inputs. Please enable it and re-run.")
                }
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
        logger.info("- ALAC compression: \(enableALAC)")
        logger.info("- AAC compression: \(enableAAC)")
        logger.info("- MP3 compression: \(enableMP3)")
        if let q = quality { logger.info("- Quality preset: \(q.rawValue)") }
        if let b = bitrate { logger.info("- Bitrate: \(b) kbps") }
        if let sr = sampleRate { logger.info("- Sample rate: \(Int(sr)) Hz") }
        if vbr { logger.info("- VBR: enabled (AAC)") }

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

        // Create capturer with knowledge of input capture and ALAC preference
        let processor = AudioProcessor(sampleRate: 48_000, channels: captureInputs ? 1 : 2)
        let capturer = AudioCapturer(permissionManager: permissionManager, fileController: FileController(), audioProcessor: processor, outputDirectoryPath: outputDirectory, captureInputsEnabled: captureInputs, alacEnabled: enableALAC, logger: logger)

        // Optional input device manager lifecycle
        var inputManager: InputDeviceManager? = nil
        var inputDelegate: CombinedInputDelegate? = nil  // Store delegate to keep it alive
        if captureInputs {
            let manager = InputDeviceManager()
            let reporter = InputStatusReporter(logger: logger)
            let combined = CombinedInputDelegate(reporter: reporter, capturer: capturer)
            manager.delegate = combined
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
            inputDelegate = combined  // Keep delegate alive
            _ = inputDelegate // Silence warning - delegate must be retained
        }

        capturer.setOutputDirectory(outputDirectory)

        // Bridge CLI lossy options to capturer via environment flags (internal)
        if enableAAC { setenv("AUDIOCAP_ENABLE_LOSSY_AAC", "1", 1) }
        if enableMP3 { setenv("AUDIOCAP_ENABLE_LOSSY_MP3", "1", 1) }
        if let b = bitrate { setenv("AUDIOCAP_BITRATE", String(b), 1) }
        if let sr = sampleRate { setenv("AUDIOCAP_SAMPLE_RATE", String(Int(sr)), 1) }
        if vbr { setenv("AUDIOCAP_VBR", "1", 1) }

        // Optional ALAC performance reporter (verbose only)
        var perfTimer: DispatchSourceTimer? = nil
        if enableALAC && verbose {
            let t = DispatchSource.makeTimerSource(queue: .global(qos: .background))
            t.schedule(deadline: .now() + 2, repeating: 2)
            t.setEventHandler {
                logger.debug("ALAC encoding active...")
            }
            perfTimer = t
            t.resume()
        }

        let shutdown = ShutdownCoordinator(audioCapturer: capturer, fileController: FileController())
        let signalHandler = SignalHandler(signalNumber: SIGINT)
        let outDir = self.outputDirectory
        signalHandler.start {
            // Stop input devices first
            if let im = inputManager {
                im.stopCapturing()
                im.stopMonitoring()
            }
            perfTimer?.cancel()
            perfTimer = nil
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

public enum CompressionQuality: String, CaseIterable, ExpressibleByArgument {
    case low
    case medium
    case high
    case maximum

    public var bitrate: UInt32 {
        switch self {
        case .low: return 64
        case .medium: return 128
        case .high: return 192
        case .maximum: return 256
        }
    }

    public var description: String {
        switch self {
        case .low: return "Low (64 kbps) - Maximum compression"
        case .medium: return "Medium (128 kbps) - Balanced quality/size"
        case .high: return "High (192 kbps) - High quality"
        case .maximum: return "Maximum (256 kbps) - Near-transparent quality"
        }
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
        // status only
    }
}

// Combined delegate forwards status logs and audio buffers to the capturer
final class CombinedInputDelegate: InputDeviceManagerDelegate {
    private let reporter: InputStatusReporter
    private weak var capturer: AudioCapturer?
    init(reporter: InputStatusReporter, capturer: AudioCapturer) {
        self.reporter = reporter
        self.capturer = capturer
    }
    func deviceConnected(_ device: AudioInputDevice, assignedToChannel channel: Int) {
        reporter.deviceConnected(device, assignedToChannel: channel)
    }
    func deviceDisconnected(_ device: AudioInputDevice, fromChannel channel: Int) {
        reporter.deviceDisconnected(device, fromChannel: channel)
    }
    func audioDataReceived(from device: AudioInputDevice, buffer: AVAudioPCMBuffer) {
        capturer?.receiveInputAudio(from: device, buffer: buffer)
    }
}
