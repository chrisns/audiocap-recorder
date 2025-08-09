import Foundation
import AVFoundation

public final class AudioProcessor: AudioProcessorProtocol {
    private let format: AVAudioFormat

    public init(sampleRate: Double = 48_000, channels: AVAudioChannelCount = 2) {
        self.format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
    }

    public func processAudioBuffer(_ sampleBuffer: CMSampleBuffer, from processes: [RecorderProcessInfo]) -> AVAudioPCMBuffer? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)

        guard let audioBufferList = AudioProcessor.copyPCMBufferList(from: blockBuffer, frameCount: numSamples) else {
            return nil
        }

        let frameCapacity = AVAudioFrameCount(numSamples)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
        pcmBuffer.frameLength = frameCapacity

        let channelCount = Int(format.channelCount)
        for channel in 0..<channelCount {
            let src = audioBufferList.pointee.mBuffers
            let dst = pcmBuffer.floatChannelData![channel]
            let samples = Int(frameCapacity)
            memcpy(dst, src.mData, samples * MemoryLayout<Float>.size)
        }

        return pcmBuffer
    }

    public func mixAudioStreams(_ streams: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard let first = streams.first else { return nil }
        let frameLength = first.frameLength
        guard let mixed = AVAudioPCMBuffer(pcmFormat: first.format, frameCapacity: frameLength) else { return nil }
        mixed.frameLength = frameLength

        guard let mixedChannels = mixed.floatChannelData else { return nil }
        let channelCount = Int(first.format.channelCount)
        let frames = Int(frameLength)

        for c in 0..<channelCount {
            let dst = mixedChannels[c]
            for i in 0..<frames { dst[i] = 0 }
        }

        for buffer in streams {
            guard let srcChannels = buffer.floatChannelData else { continue }
            let srcFrames = Int(buffer.frameLength)
            for c in 0..<channelCount {
                let dst = mixedChannels[c]
                let src = srcChannels[c]
                let count = min(frames, srcFrames)
                for i in 0..<count { dst[i] += src[i] }
            }
        }

        return mixed
    }

    public func convertToWAV(_ buffer: AVAudioPCMBuffer) -> Data {
        // Write the buffer directly to a temporary WAV file using its current format
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

private extension AudioProcessor {
    static func copyPCMBufferList(from blockBuffer: CMBlockBuffer, frameCount: Int) -> UnsafePointer<AudioBufferList>? {
        var audioBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(frameCount * MemoryLayout<Float>.size), mData: nil))
        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)
        guard status == kCMBlockBufferNoErr else { return nil }
        audioBufferList.mBuffers.mData = UnsafeMutableRawPointer(dataPointer)
        audioBufferList.mBuffers.mDataByteSize = UInt32(totalLength)
        return withUnsafePointer(to: &audioBufferList) { $0 }
    }
}
