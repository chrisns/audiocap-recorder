@preconcurrency import AVFoundation
import Foundation
import ScreenCaptureKit
import AppKit

public final class AudioCapturer: NSObject, AudioCapturerProtocol {
    public weak var delegate: AudioCapturerDelegate?

    private let permissionManager: PermissionManaging
    private var stream: SCStream?
    private let sampleQueue = DispatchQueue(label: "audio.capturer.samples")
    private var recordingTimer: RecordingTimer?

    private let fileController: FileControllerProtocol
    private let audioProcessor: AudioProcessorProtocol
    private var outputDirectoryPath: String?
    private let logger: Logger?

    private var outputFile: AVAudioFile?
    private var outputURL: URL?

    private let captureInputsEnabled: Bool
    private let inputSyncQueue = DispatchQueue(label: "audio.capturer.inputs")
    private var latestInputByChannel: [Int: AVAudioPCMBuffer] = [:]
    
    // Synchronization for multichannel writing
    private let writeQueue = DispatchQueue(label: "audio.capturer.write")
    private var writeTimer: DispatchSourceTimer?
    private let writeInterval: TimeInterval = 0.005 // Write every 5ms (240 samples at 48kHz)
    
    // Ring buffers for accumulating audio
    private var processRingBuffer: RingBuffer?
    private var inputRingBuffers: [Int: RingBuffer] = [:]
    
    private let alacEnabled: Bool
    private var writeAvgMs: Double = 0

    // Lossy compression support (AAC/MP3)
    private var compressionController: CompressionController?
    private var compressionFormat: CompressionConfiguration.CompressionFormat = .uncompressed
    private var lastProgressLog: TimeInterval = 0

    public init(
        permissionManager: PermissionManaging = PermissionManager(),
        fileController: FileControllerProtocol = FileController(),
        audioProcessor: AudioProcessorProtocol = AudioProcessor(),
        outputDirectoryPath: String? = nil,
        captureInputsEnabled: Bool = false,
        alacEnabled: Bool = false,
        logger: Logger? = nil
    ) {
        self.permissionManager = permissionManager
        self.fileController = fileController
        self.audioProcessor = audioProcessor
        self.outputDirectoryPath = outputDirectoryPath
        self.captureInputsEnabled = captureInputsEnabled
        self.alacEnabled = alacEnabled
        self.logger = logger
        super.init()
    }

    public func setOutputDirectory(_ path: String?) {
        self.outputDirectoryPath = path
    }
}

extension AudioCapturer {
    public func startCapture(for processes: [RecorderProcessInfo]) async throws {
        guard permissionManager.checkScreenRecordingPermission() else {
            throw AudioRecorderError.permissionDenied(.screenRecording)
        }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2
        config.excludesCurrentProcessAudio = true

        let content = try await SCShareableContent.current
        guard let display = preferredDisplay(from: content.displays) else {
            throw AudioRecorderError.configurationError("No display available for content filter")
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: SCStreamOutputType.audio, sampleHandlerQueue: sampleQueue)

        // Resolve output directory strictly with fallback
        let dirURL: URL
        if let path = outputDirectoryPath, !path.isEmpty {
            do {
                try fileController.createOutputDirectory(path)
                dirURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: true)
            } catch {
                let fallback = fileController.defaultOutputDirectory()
                do {
                    try FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
                    dirURL = fallback
                } catch {
                    throw AudioRecorderError.fileSystemError("Failed to create output directory at \(path) and fallback default directory")
                }
            }
        } else {
            let fallback = fileController.defaultOutputDirectory()
            do {
                try FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
                dirURL = fallback
            } catch {
                throw AudioRecorderError.fileSystemError("Failed to create default output directory at \(fallback.path)")
            }
        }
        // Choose extension based on ALAC preference
        let outExt = alacEnabled ? "m4a" : "caf"
        self.outputURL = dirURL.appendingPathComponent(fileController.generateTimestampedFilename(extension: outExt))
        if let url = self.outputURL { logger?.info("- Output file: \(url.path)") }

        // Open writer
        if captureInputsEnabled {
            // Multi-channel path (8ch) using AVAudioFile for both CAF and ALAC
            guard let url = self.outputURL else { throw AudioRecorderError.fileSystemError("Missing output URL") }
            if alacEnabled {
                do {
                    let cfg = ALACConfiguration(sampleRate: 48_000, channelCount: 8, bitDepth: 16, quality: .max)
                    let settings = try ALACConfigurator.alacSettings(for: cfg)
                    self.outputFile = try AVAudioFile(forWriting: url, settings: settings)
                } catch {
                    // Fallback to CAF Float32 interleaved - create directly with settings
                    let settings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: 48_000,
                        AVNumberOfChannelsKey: 8,
                        AVLinearPCMBitDepthKey: 32,
                        AVLinearPCMIsFloatKey: true,
                        AVLinearPCMIsBigEndianKey: false,
                        AVLinearPCMIsNonInterleaved: false
                    ]
                    let fallbackURL = dirURL.appendingPathComponent(fileController.generateTimestampedFilename(extension: "caf"))
                    self.outputURL = fallbackURL
                    self.outputFile = try AVAudioFile(forWriting: fallbackURL, settings: settings)
                }
            } else {
                // CAF Float32 interleaved - create directly with settings
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 48_000,
                    AVNumberOfChannelsKey: 8,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
                self.outputFile = try AVAudioFile(forWriting: url, settings: settings)
            }
            // Initialize ring buffers (1 second capacity)
            let bufferCapacity = 48_000
            self.processRingBuffer = RingBuffer(capacity: bufferCapacity)
            for channel in 2...8 {
                self.inputRingBuffers[channel] = RingBuffer(capacity: bufferCapacity)
            }
            // Start write timer
            startWriteTimer()
        } else {
            // Mono path with optional lossy compression (AAC/MP3) and fallback
            if alacEnabled {
                guard let url = self.outputURL else { throw AudioRecorderError.fileSystemError("Missing output URL") }
                do {
                    let cfg = ALACConfiguration(sampleRate: 48_000, channelCount: 1, bitDepth: 16, quality: .max)
                    let settings = try ALACConfigurator.alacSettings(for: cfg)
                    self.outputFile = try AVAudioFile(forWriting: url, settings: settings)
                    self.compressionFormat = .alac
                } catch {
                    // Fallback to mono CAF
                    let fallbackURL = dirURL.appendingPathComponent(fileController.generateTimestampedFilename(extension: "caf"))
                    let mono = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)!
                    self.outputURL = fallbackURL
                    self.outputFile = try AVAudioFile(forWriting: fallbackURL, settings: mono.settings)
                    self.compressionFormat = .uncompressed
                }
            } else {
                // Default stereo CAF using AVAudioFile for stronger signal presence in analysis
                let stereo = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: false)!
                self.outputFile = try AVAudioFile(forWriting: self.outputURL!, settings: stereo.settings)
                self.compressionFormat = .uncompressed
            }

            // Initialize lossy compression controller if requested via environment (internal hook used by CLI layer)
            if ProcessInfo.processInfo.environment["AUDIOCAP_ENABLE_LOSSY_AAC"] == "1" || ProcessInfo.processInfo.environment["AUDIOCAP_ENABLE_LOSSY_MP3"] == "1" {
                var format: CompressionConfiguration.CompressionFormat = .aac
                if ProcessInfo.processInfo.environment["AUDIOCAP_ENABLE_LOSSY_MP3"] == "1" { format = .mp3 }
                self.compressionFormat = format
                let bitrateEnv = UInt32(ProcessInfo.processInfo.environment["AUDIOCAP_BITRATE"] ?? "128") ?? 128
                let sampleRateEnv = Double(ProcessInfo.processInfo.environment["AUDIOCAP_SAMPLE_RATE"] ?? "48000") ?? 48000
                let vbrEnv = ProcessInfo.processInfo.environment["AUDIOCAP_VBR"] == "1"
                let config = CompressionConfiguration(
                    format: format,
                    bitrate: bitrateEnv,
                    quality: nil,
                    enableVBR: vbrEnv,
                    sampleRate: sampleRateEnv,
                    channelCount: 1,
                    enableMultiChannel: false
                )
                let controller = CompressionController()
                do {
                    try controller.initializeWithCompatibility(config)
                    self.compressionController = controller
                    self.logger?.info("Lossy compression initialized: format=\(format.displayName) bitrate=\(bitrateEnv)kbps sampleRate=\(Int(sampleRateEnv))Hz")
                } catch let err as AudioRecorderError {
                    // Report but continue with uncompressed mono
                    self.logger?.warn("Lossy compression disabled due to error: \(err.localizedDescription)")
                    self.delegate?.didEncounterError(err)
                    self.compressionController = nil
                    self.compressionFormat = .uncompressed
                } catch {
                    self.logger?.warn("Lossy compression disabled due to error: \(error.localizedDescription)")
                    self.compressionController = nil
                    self.compressionFormat = .uncompressed
                }
            }
        }

        try await stream.startCapture()
        self.stream = stream
        delegate?.didStartRecording()
        self.recordingTimer = nil
    }

    public func stopCapture() {
        recordingTimer?.stop()
        recordingTimer = nil
        
        if captureInputsEnabled { stopWriteTimer() }
        
        stream?.stopCapture { [weak self] error in
            if let error = error {
                self?.delegate?.didEncounterError(.audioCaptureFailed(error.localizedDescription))
            }
        }
        stream = nil
        
        if let url = self.outputURL { delegate?.didStopRecording(outputFileURL: url) }
        
        outputFile = nil
        
        // Clean up ring buffers
        processRingBuffer = nil
        inputRingBuffers.removeAll()
    }
}

extension AudioCapturer: SCStreamOutput, SCStreamDelegate {
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio else { return }
        
        do {
            if captureInputsEnabled {
                guard let pcmMono = audioProcessor.processAudioBuffer(sampleBuffer, from: []) else { return }
                
                // Write to process ring buffer
                if let processData = pcmMono.floatChannelData?[0] {
                    processRingBuffer?.write(processData, frameCount: Int(pcmMono.frameLength))
                }
            } else {
                guard let file = self.outputFile,
                      let pcmBuffer = audioProcessor.processAudioBuffer(sampleBuffer, from: []) else { return }

                // Route to lossy compression when configured; on failure, fallback to writing CAF directly
                if let controller = self.compressionController {
                    do {
                        _ = try controller.processAudioBuffer(pcmBuffer)
                        // Periodic progress logging every ~2 seconds when verbose
                        if logger?.isVerbose == true {
                            let now = Date().timeIntervalSince1970
                            if now - lastProgressLog > 2.0 {
                                if let p = controller.getCompressionProgress() {
                                    let kb = Double(p.bytesProcessed) / 1024.0
                                    let est = Double(p.estimatedTotalBytes) / 1024.0
                                    let speed = p.encodingSpeedMBps
                                    let pct = Int(p.compressionRatio * 100.0)
                                    let elapsed = Int(p.elapsedSeconds)
                                    let cpu = Int(p.cpuUsagePercent)
                                    var etaText = ""
                                    if let maxStr = ProcessInfo.processInfo.environment["AUDIOCAP_MAX_DURATION_SEC"], let max = Int(maxStr), max > elapsed {
                                        let remaining = max - elapsed
                                        etaText = String(format: " eta=%ds", remaining)
                                    }
                                    logger?.info(String(format: "Compression: t=%ds processed=%.1f KB estOut=%.1f KB savings=%d%% speed=%.2f MB/s cpu=%d%%%@", elapsed, kb, est, pct, speed, cpu, etaText))
                                    lastProgressLog = now
                                }
                            }
                        }
                    } catch let err as AudioRecorderError {
                        // Notify and disable compression; continue writing uncompressed
                        self.delegate?.didEncounterError(err)
                        self.logger?.warn("Compression error encountered. Falling back to uncompressed: \(err.localizedDescription)")
                        self.compressionController = nil
                        self.compressionFormat = .uncompressed
                        try file.write(from: pcmBuffer)
                    } catch {
                        self.logger?.warn("Compression error encountered. Falling back to uncompressed: \(error.localizedDescription)")
                        self.compressionController = nil
                        self.compressionFormat = .uncompressed
                        try file.write(from: pcmBuffer)
                    }
                } else {
                    try file.write(from: pcmBuffer)
                }
            }
        } catch {
            delegate?.didEncounterError(.fileSystemError(error.localizedDescription))
        }
    }

    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        delegate?.didEncounterError(.audioCaptureFailed(error.localizedDescription))
    }
}

public extension AudioCapturer {
    func receiveInputAudio(from device: AudioInputDevice, buffer: AVAudioPCMBuffer) {
        guard captureInputsEnabled, let channel = device.assignedChannel else { return }
        
        // Write to input ring buffer
        if let inputData = buffer.floatChannelData?[0],
           let ringBuffer = self.inputRingBuffers[channel] {
            ringBuffer.write(inputData, frameCount: Int(buffer.frameLength))
        }
        
        // Ensure multichannel file grows even if SC audio is silent by triggering a write
        if outputFile != nil {
            writeQueue.async { [weak self] in
                self?.writeAudioFrame()
            }
        }
    }
}

private extension AudioCapturer {
    func startWriteTimer() {
        let timer = DispatchSource.makeTimerSource(queue: writeQueue)
        timer.schedule(deadline: .now(), repeating: writeInterval)
        timer.setEventHandler { [weak self] in
            self?.writeAudioFrame()
        }
        timer.resume()
        self.writeTimer = timer
    }
    
    func stopWriteTimer() {
        writeTimer?.cancel()
        writeTimer = nil
    }
    
    func writeAudioFrame() {
        guard let file = self.outputFile else { return }
        let framesToWrite = Int(writeInterval * 48_000)
        
        // Use the file's processing format to ensure compatibility
        let fmt = file.processingFormat
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(framesToWrite)) else { return }
        buf.frameLength = AVAudioFrameCount(framesToWrite)
        
        // Check if format is interleaved or non-interleaved
        if fmt.isInterleaved {
            // Interleaved format
            guard let data = buf.floatChannelData?[0] else { return }
            
            // Create temporary arrays to read from ring buffers
            var processData = [Float](repeating: 0, count: framesToWrite)
            var inputData = [[Float]](repeating: [Float](repeating: 0, count: framesToWrite), count: 7)
            
            // Read from ring buffers
            if let ringBuffer = self.processRingBuffer {
                _ = ringBuffer.read(into: &processData, frameCount: framesToWrite)
            }
            
            for i in 0..<7 {
                if let ringBuffer = self.inputRingBuffers[i + 2] {
                    _ = ringBuffer.read(into: &inputData[i], frameCount: framesToWrite)
                }
            }
            
            // Interleave the data
            for frame in 0..<framesToWrite {
                let baseIndex = frame * 8
                data[baseIndex] = processData[frame]  // Channel 0
                for ch in 0..<7 {
                    data[baseIndex + ch + 1] = inputData[ch][frame]  // Channels 1-7
                }
            }
        } else {
            // Non-interleaved format
            guard let channels = buf.floatChannelData else { return }
            
            // Channel 0: Process
            if let ringBuffer = self.processRingBuffer {
                _ = ringBuffer.read(into: channels[0], frameCount: framesToWrite)
            } else {
                memset(channels[0], 0, framesToWrite * MemoryLayout<Float>.size)
            }
            
            // Channels 1-7: Inputs (ring buffers are indexed 2-8)
            for channel in 1..<8 {
                let ringBufferIndex = channel + 1
                if let ringBuffer = self.inputRingBuffers[ringBufferIndex] {
                    _ = ringBuffer.read(into: channels[channel], frameCount: framesToWrite)
                } else {
                    memset(channels[channel], 0, framesToWrite * MemoryLayout<Float>.size)
                }
            }
        }
        let start = mach_absolute_time()
        do {
            try file.write(from: buf)
        } catch {
            delegate?.didEncounterError(.fileSystemError("AVAudioFile write failed: \(error.localizedDescription)"))
        }
        let end = mach_absolute_time()
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let ns = (end - start) * UInt64(timebase.numer) / UInt64(timebase.denom)
        let ms = Double(ns) / 1_000_000.0
        writeAvgMs = (writeAvgMs * 0.9) + (ms * 0.1)
    }
    
    func preferredDisplay(from displays: [SCDisplay]) -> SCDisplay? {
        if let mainScreen = NSScreen.main, let id = mainScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            return displays.first { $0.displayID == id }
        }
        return displays.first
    }
}

// Add InputDeviceManagerDelegate conformance
extension AudioCapturer: InputDeviceManagerDelegate {
    public func deviceConnected(_ device: AudioInputDevice, assignedToChannel channel: Int) { }
    public func deviceDisconnected(_ device: AudioInputDevice, fromChannel channel: Int) { }
    public func audioDataReceived(from device: AudioInputDevice, buffer: AVAudioPCMBuffer) { receiveInputAudio(from: device, buffer: buffer) }
}
