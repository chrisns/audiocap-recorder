@preconcurrency import AVFoundation
@preconcurrency import AudioToolbox
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

    private var outputFile: AVAudioFile?
    private var outputURL: URL?

    private let captureInputsEnabled: Bool
    private let inputSyncQueue = DispatchQueue(label: "audio.capturer.inputs")
    private var latestInputByChannel: [Int: AVAudioPCMBuffer] = [:]

    private var extAudioFile: ExtAudioFileRef?

    public init(
        permissionManager: PermissionManaging = PermissionManager(),
        fileController: FileControllerProtocol = FileController(),
        audioProcessor: AudioProcessorProtocol = AudioProcessor(),
        outputDirectoryPath: String? = nil,
        captureInputsEnabled: Bool = false
    ) {
        self.permissionManager = permissionManager
        self.fileController = fileController
        self.audioProcessor = audioProcessor
        self.outputDirectoryPath = outputDirectoryPath
        self.captureInputsEnabled = captureInputsEnabled
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
        self.outputURL = dirURL.appendingPathComponent(fileController.generateTimestampedFilename(extension: "caf"))

        // Open writer
        if captureInputsEnabled {
            // ExtAudioFile: Destination 8ch Float32 INTERLEAVED CAF; Client 8ch Float32 NON-INTERLEAVED
            guard let url = self.outputURL else { throw AudioRecorderError.fileSystemError("Missing output URL") }
            var dst = AudioStreamBasicDescription(
                mSampleRate: 48_000,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 8 * 4,
                mFramesPerPacket: 1,
                mBytesPerFrame: 8 * 4,
                mChannelsPerFrame: 8,
                mBitsPerChannel: 32,
                mReserved: 0
            )
            var ref: ExtAudioFileRef? = nil
            let status = ExtAudioFileCreateWithURL(url as CFURL, kAudioFileCAFType, &dst, nil, AudioFileFlags.eraseFile.rawValue, &ref)
            guard status == noErr, let extRef = ref else {
                throw AudioRecorderError.fileSystemError("Failed to create CAF file at \(url.path), status=\(status)")
            }
            var client = AudioStreamBasicDescription(
                mSampleRate: 48_000,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
                mBytesPerPacket: 4,
                mFramesPerPacket: 1,
                mBytesPerFrame: 4,
                mChannelsPerFrame: 8,
                mBitsPerChannel: 32,
                mReserved: 0
            )
            let set = ExtAudioFileSetProperty(extRef, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &client)
            if set != noErr { ExtAudioFileDispose(extRef); throw AudioRecorderError.fileSystemError("Failed to set client format, status=\(set)") }
            self.extAudioFile = extRef
            // Seed file with a small block of silence
            writeSilence(frames: 1024)
        } else {
            // Stereo CAF using AVAudioFile
            let stereo = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: false)!
            self.outputFile = try AVAudioFile(forWriting: self.outputURL!, settings: stereo.settings)
        }

        try await stream.startCapture()
        self.stream = stream
        delegate?.didStartRecording()
        self.recordingTimer = nil
    }

    public func stopCapture() {
        recordingTimer?.stop(); recordingTimer = nil
        let currentStream = self.stream; self.stream = nil
        if let s = currentStream { s.stopCapture(completionHandler: { _ in }) }
        if let url = self.outputURL { delegate?.didStopRecording(outputFileURL: url) }
        if let ext = extAudioFile { ExtAudioFileDispose(ext) }
        extAudioFile = nil
        outputFile = nil
    }
}

extension AudioCapturer: SCStreamOutput, SCStreamDelegate {
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio else { return }
        do {
            if captureInputsEnabled {
                guard let ext = self.extAudioFile else { return }
                guard let pcmStereo = audioProcessor.processAudioBuffer(sampleBuffer, from: []) else { return }
                let frames = Int(pcmStereo.frameLength)
                if frames <= 0 { return }
                // Build non-interleaved 8ch buffer list with process on ch 1-2
                withTemporaryABL(channelCount: 8, frames: frames) { abl, channels in
                    if let procCh = pcmStereo.floatChannelData {
                        memcpy(channels[0], procCh[0], frames * MemoryLayout<Float>.size)
                        if pcmStereo.format.channelCount >= 2 {
                            memcpy(channels[1], procCh[1], frames * MemoryLayout<Float>.size)
                        } else {
                            memcpy(channels[1], procCh[0], frames * MemoryLayout<Float>.size)
                        }
                    }
                    let status = ExtAudioFileWrite(ext, UInt32(frames), abl)
                    if status != noErr {
                        delegate?.didEncounterError(.fileSystemError("ExtAudioFileWrite failed: \(status)"))
                    }
                }
            } else {
                guard let file = self.outputFile,
                      let pcmStereo = audioProcessor.processAudioBuffer(sampleBuffer, from: []) else { return }
                try file.write(from: pcmStereo)
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
        guard captureInputsEnabled, let channel = device.assignedChannel, let ext = self.extAudioFile else { return }
        inputSyncQueue.async { self.latestInputByChannel[channel] = buffer }
        // Synchronous write to avoid Sendable capture issues
        let targetIndex = channel - 1
        let frames = Int(buffer.frameLength)
        guard frames > 0, targetIndex >= 0, targetIndex < 8 else { return }
        
        self.withTemporaryABL(channelCount: 8, frames: frames) { abl, channels in
            if let src = buffer.floatChannelData {
                memcpy(channels[targetIndex], src[0], frames * MemoryLayout<Float>.size)
            }
            let status = ExtAudioFileWrite(ext, UInt32(frames), abl)
            if status != noErr {
                self.delegate?.didEncounterError(.fileSystemError("ExtAudioFileWrite (input) failed: \(status)"))
            }
        }
    }
}

private extension AudioCapturer {
    func preferredDisplay(from displays: [SCDisplay]) -> SCDisplay? {
        if let mainScreen = NSScreen.main, let id = mainScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            return displays.first { $0.displayID == id }
        }
        return displays.first
    }

    // Allocate a non-interleaved AudioBufferList with given channels and frames, zero-filled, and provide per-channel pointers
    func withTemporaryABL(channelCount: Int, frames: Int, _ body: (_ abl: UnsafePointer<AudioBufferList>, _ channels: [UnsafeMutablePointer<Float>]) -> Void) {
        let ablSize = MemoryLayout<AudioBufferList>.size + (channelCount - 1) * MemoryLayout<AudioBuffer>.size
        let raw = UnsafeMutableRawPointer.allocate(byteCount: ablSize, alignment: MemoryLayout<AudioBufferList>.alignment)
        raw.initializeMemory(as: UInt8.self, repeating: 0, count: ablSize)
        let ablPtr = raw.bindMemory(to: AudioBufferList.self, capacity: 1)

        var chanPtrs: [UnsafeMutablePointer<Float>] = []
        chanPtrs.reserveCapacity(channelCount)
        for _ in 0..<channelCount {
            let p = UnsafeMutablePointer<Float>.allocate(capacity: frames)
            p.initialize(repeating: 0, count: frames)
            chanPtrs.append(p)
        }
        ablPtr.pointee.mNumberBuffers = UInt32(channelCount)
        let bufList = UnsafeMutableAudioBufferListPointer(ablPtr)
        for i in 0..<channelCount {
            bufList[i].mNumberChannels = 1
            bufList[i].mDataByteSize = UInt32(frames * MemoryLayout<Float>.size)
            bufList[i].mData = UnsafeMutableRawPointer(chanPtrs[i])
        }
        body(UnsafePointer(ablPtr), chanPtrs)
        for p in chanPtrs { p.deallocate() }
        raw.deallocate()
    }

    func writeSilence(frames: Int) {
        guard let ext = self.extAudioFile else { return }
        withTemporaryABL(channelCount: 8, frames: frames) { abl, _ in
            _ = ExtAudioFileWrite(ext, UInt32(frames), abl)
        }
    }
}

// Add InputDeviceManagerDelegate conformance
extension AudioCapturer: InputDeviceManagerDelegate {
    public func deviceConnected(_ device: AudioInputDevice, assignedToChannel channel: Int) {
        // Log device connection
    }
    
    public func deviceDisconnected(_ device: AudioInputDevice, fromChannel channel: Int) {
        // Log device disconnection
    }
    
    public func audioDataReceived(from device: AudioInputDevice, buffer: AVAudioPCMBuffer) {
        receiveInputAudio(from: device, buffer: buffer)
    }
}
