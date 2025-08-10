import Foundation
import AVFoundation
import Accelerate

public final class AudioProcessor: AudioProcessorProtocol {
    private let targetFormat: AVAudioFormat
    private var compressionEngine: CompressionEngineProtocol?

    public init(sampleRate: Double = 48_000, channels: AVAudioChannelCount = 1) {
        self.targetFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
    }

    // Allows wiring in a compression engine (AAC/MP3)
    public func setCompressionEngine(_ engine: CompressionEngineProtocol?) {
        self.compressionEngine = engine
    }

    public func processAudioBuffer(_ sampleBuffer: CMSampleBuffer, from processes: [RecorderProcessInfo]) -> AVAudioPCMBuffer? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else {
            return nil
        }
        let asbd = asbdPtr.pointee
        let sourceChannels = Int(asbd.mChannelsPerFrame)
        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frames > 0, sourceChannels > 0 else { return nil }

        // Prepare destination buffer (48kHz mono float)
        guard let dest = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frames) else { return nil }
        dest.frameLength = frames
        guard let destChannels = dest.floatChannelData else { return nil }
        let frameCount = Int(frames)

        // Allocate a properly sized AudioBufferList backing memory
        let ablSize = MemoryLayout<AudioBufferList>.size + MemoryLayout<AudioBuffer>.size * (max(sourceChannels, 1) - 1)
        let rawPtr = UnsafeMutableRawPointer.allocate(byteCount: ablSize, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { rawPtr.deallocate() }
        rawPtr.initializeMemory(as: UInt8.self, repeating: 0, count: ablSize)
        let ablPtr = rawPtr.bindMemory(to: AudioBufferList.self, capacity: 1)

        var blockBuffer: CMBlockBuffer? = nil
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: ablPtr,
            bufferListSize: ablSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return nil }

        let audioList = UnsafeMutableAudioBufferListPointer(ablPtr)
        let destMono = destChannels[0]
        
        if audioList.count >= 2 {
            // Planar float: mix channels to mono
            memset(destMono, 0, frameCount * MemoryLayout<Float>.size)
            for ch in 0..<min(sourceChannels, audioList.count) {
                let buf = audioList[ch]
                guard let mData = buf.mData else { continue }
                let src = mData.assumingMemoryBound(to: Float.self)
                // Mix into mono with equal gain
                let gain = 1.0 / Float(sourceChannels)
                vDSP_vsma(src, 1, [gain], destMono, 1, destMono, 1, vDSP_Length(frameCount))
            }
        } else if audioList.count == 1 {
            // Interleaved float: extract and mix to mono
            let buf = audioList[0]
            guard let mData = buf.mData else { return dest }
            let src = mData.assumingMemoryBound(to: Float.self)
            
            if sourceChannels >= 2 {
                // Mix stereo/multichannel to mono
                memset(destMono, 0, frameCount * MemoryLayout<Float>.size)
                for ch in 0..<sourceChannels {
                    var channelSrc = [Float](repeating: 0, count: frameCount)
                    for i in 0..<frameCount {
                        channelSrc[i] = src[i * sourceChannels + ch]
                    }
                    let gain = 1.0 / Float(sourceChannels)
                    vDSP_vsma(channelSrc, 1, [gain], destMono, 1, destMono, 1, vDSP_Length(frameCount))
                }
            } else if sourceChannels == 1 {
                // Already mono, just copy
                memcpy(destMono, src, frameCount * MemoryLayout<Float>.size)
            }
        }

        return dest
    }

    public func mixAudioStreams(_ streams: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard let first = streams.first else { return nil }
        let frameLength = first.frameLength
        guard let mixed = AVAudioPCMBuffer(pcmFormat: first.format, frameCapacity: frameLength) else { return nil }
        mixed.frameLength = frameLength

        guard let mixedChannels = mixed.floatChannelData else { return nil }
        let channelCount = Int(first.format.channelCount)
        let frames = Int(frameLength)

        for c in 0..<channelCount { memset(mixedChannels[c], 0, frames * MemoryLayout<Float>.size) }

        for buffer in streams {
            guard let srcChannels = buffer.floatChannelData else { continue }
            let srcFrames = Int(buffer.frameLength)
            for c in 0..<channelCount {
                let dst = mixedChannels[c]
                let src = srcChannels[c]
                let count = min(frames, srcFrames)
                vDSP_vadd(src, 1, dst, 1, dst, 1, vDSP_Length(count))
            }
        }

        return mixed
    }

    public func convertToWAV(_ buffer: AVAudioPCMBuffer) -> Data {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".wav")
        do {
            let file = try AVAudioFile(forWriting: url, settings: buffer.format.settings)
            try file.write(from: buffer)
            return try Data(contentsOf: url)
        } catch {
            return Data()
        }
    }

    public func combine(processAudio: AVAudioPCMBuffer, inputAudioByChannel: [Int: AVAudioPCMBuffer], totalChannels: Int) -> AVAudioPCMBuffer? {
        guard totalChannels >= 2 else { return nil }
        let sampleRate = processAudio.format.sampleRate

        // Build explicit ASBD for Float32 non-interleaved N-channel
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: UInt32(totalChannels),
            mBitsPerChannel: 32,
            mReserved: 0
        )
        guard let fmt = AVAudioFormat(streamDescription: &asbd) else { return nil }

        let frames = processAudio.frameLength
        guard frames > 0, let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames) else { return nil }
        out.frameLength = frames
        guard let outCh = out.floatChannelData else { return nil }

        let framesInt = Int(frames)
        for c in 0..<totalChannels { memset(outCh[c], 0, framesInt * MemoryLayout<Float>.size) }

        if let procCh = processAudio.floatChannelData {
            let count = min(framesInt, Int(processAudio.frameLength))
            memcpy(outCh[0], procCh[0], count * MemoryLayout<Float>.size)
            if processAudio.format.channelCount >= 2 {
                memcpy(outCh[1], procCh[1], count * MemoryLayout<Float>.size)
            } else {
                memcpy(outCh[1], procCh[0], count * MemoryLayout<Float>.size)
            }
        }

        for (channel, buffer) in inputAudioByChannel {
            guard channel >= 3, channel <= totalChannels else { continue }
            let idx = channel - 1
            guard let src = buffer.floatChannelData else { continue }
            let count = min(framesInt, Int(buffer.frameLength))
            memcpy(outCh[idx], src[0], count * MemoryLayout<Float>.size)
        }

        return out
    }

    // MARK: - Format conversion helper
    public func convert(buffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) -> AVAudioPCMBuffer {
        if buffer.format.sampleRate == targetFormat.sampleRate && buffer.format.channelCount == targetFormat.channelCount && buffer.format.commonFormat == targetFormat.commonFormat && buffer.format.isInterleaved == targetFormat.isInterleaved {
            return buffer
        }
        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else { return buffer }
        let frameCapacity = AVAudioFrameCount(buffer.frameLength)
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else { return buffer }
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        converter.convert(to: out, error: &error, withInputFrom: inputBlock)
        if let _ = error { return buffer }
        out.frameLength = min(out.frameCapacity, buffer.frameLength)
        return out
    }

    // MARK: - ALAC compatibility
    public func alacCompatiblePCM(buffer: AVAudioPCMBuffer, config: ALACConfiguration) -> AVAudioPCMBuffer? {
        // Convert float32 mono/non-interleaved into interleaved Int16 with given channel count
        guard let pcmInt16 = try? ALACConfigurator.pcmClientFormat(for: config) else { return nil }
        return convert(buffer: buffer, to: pcmInt16)
    }

    public func recommendedALACBufferFrames(sampleRate: Double = 48_000) -> AVAudioFrameCount {
        // Favor larger buffers for better compression efficiency
        // Use ~4096 frames (~85ms at 48k)
        return 4096
    }

    // MARK: - Compression routing
    public func routeToCompression(buffer: AVAudioPCMBuffer, desiredFormat: AVAudioFormat?) {
        let toSend: AVAudioPCMBuffer
        if let fmt = desiredFormat {
            toSend = convert(buffer: buffer, to: fmt)
        } else {
            toSend = buffer
        }
        _ = try? compressionEngine?.processAudioBuffer(toSend)
    }

    public func processAndRoute(sampleBuffer: CMSampleBuffer, processes: [RecorderProcessInfo], desiredFormat: AVAudioFormat?) -> AVAudioPCMBuffer? {
        guard let mono = processAudioBuffer(sampleBuffer, from: processes) else { return nil }
        routeToCompression(buffer: mono, desiredFormat: desiredFormat)
        return mono
    }

    private func bufferDuration(_ buffer: AVAudioPCMBuffer) -> TimeInterval {
        return TimeInterval(buffer.frameLength) / buffer.format.sampleRate
    }
}
