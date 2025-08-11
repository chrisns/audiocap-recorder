import Foundation
@preconcurrency import AVFoundation

final class BufferPool {
    struct Key: Hashable {
        let sampleRate: Double
        let channels: UInt32
        let interleaved: Bool
        let frameCapacity: AVAudioFrameCount
    }

    private struct Entry {
        var buffer: AVAudioPCMBuffer
        var inUse: Bool
    }

    private var pools: [Key: [Entry]] = [:]
    private let lock = NSLock()
    private let maxPerKey = 8

    func rent(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        let key = Key(sampleRate: format.sampleRate, channels: UInt32(format.channelCount), interleaved: format.isInterleaved, frameCapacity: frameCapacity)
        lock.lock(); defer { lock.unlock() }
        if var list = pools[key] {
            if let idx = list.firstIndex(where: { !$0.inUse }) {
                list[idx].inUse = true
                pools[key] = list
                return list[idx].buffer
            }
            if list.count < maxPerKey, let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) {
                pools[key] = list + [Entry(buffer: buf, inUse: true)]
                return buf
            }
            return nil
        } else {
            guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
            pools[key] = [Entry(buffer: buf, inUse: true)]
            return buf
        }
    }

    func giveBack(_ buffer: AVAudioPCMBuffer) {
        let fmt = buffer.format
        let key = Key(sampleRate: fmt.sampleRate, channels: UInt32(fmt.channelCount), interleaved: fmt.isInterleaved, frameCapacity: buffer.frameCapacity)
        lock.lock(); defer { lock.unlock() }
        guard var list = pools[key] else { return }
        if let idx = list.firstIndex(where: { $0.buffer === buffer }) {
            list[idx].inUse = false
            pools[key] = list
        }
    }
}
