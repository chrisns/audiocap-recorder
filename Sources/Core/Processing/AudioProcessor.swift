import Foundation
import AVFoundation
import Accelerate

public final class AudioProcessor: AudioProcessorProtocol {
    private let targetFormat: AVAudioFormat

    public init(sampleRate: Double = 48_000, channels: AVAudioChannelCount = 2) {
        self.targetFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
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

        // Prepare destination buffer (48kHz stereo float)
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
        if audioList.count >= 2 {
            // Planar float: one buffer per channel
            for ch in 0..<min(2, audioList.count) {
                let buf = audioList[ch]
                guard let mData = buf.mData else { continue }
                memcpy(destChannels[ch], mData, min(Int(buf.mDataByteSize), frameCount * MemoryLayout<Float>.size))
            }
            if audioList.count == 1 {
                memcpy(destChannels[1], destChannels[0], frameCount * MemoryLayout<Float>.size)
            }
        } else if audioList.count == 1 {
            // Interleaved float
            let buf = audioList[0]
            guard let mData = buf.mData else { return dest }
            let src = mData.assumingMemoryBound(to: Float.self)
            var idx = 0
            if sourceChannels >= 2 {
                for i in 0..<frameCount {
                    destChannels[0][i] = src[idx]
                    destChannels[1][i] = src[idx + 1]
                    idx += sourceChannels
                }
            } else if sourceChannels == 1 {
                memcpy(destChannels[0], src, frameCount * MemoryLayout<Float>.size)
                memcpy(destChannels[1], src, frameCount * MemoryLayout<Float>.size)
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

    private func bufferDuration(_ buffer: AVAudioPCMBuffer) -> TimeInterval {
        return TimeInterval(buffer.frameLength) / buffer.format.sampleRate
    }
}
