import Foundation

final class RingBuffer {
    private var buffer: [Float]
    private let capacity: Int
    private var writeIndex: Int = 0
    private var availableFrames: Int = 0
    private let lock = NSLock()
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: 0, count: capacity)
    }
    
    func write(_ data: UnsafePointer<Float>, frameCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        let framesToWrite = min(frameCount, capacity - availableFrames)
        
        for i in 0..<framesToWrite {
            buffer[(writeIndex + i) % capacity] = data[i]
        }
        
        writeIndex = (writeIndex + framesToWrite) % capacity
        availableFrames = min(availableFrames + framesToWrite, capacity)
    }
    
    func read(into output: UnsafeMutablePointer<Float>, frameCount: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        
        let framesToRead = min(frameCount, availableFrames)
        let readIndex = (writeIndex - availableFrames + capacity) % capacity
        
        for i in 0..<framesToRead {
            output[i] = buffer[(readIndex + i) % capacity]
        }
        
        // Fill remaining with silence
        for i in framesToRead..<frameCount {
            output[i] = 0
        }
        
        availableFrames -= framesToRead
        return framesToRead
    }
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        availableFrames = 0
        writeIndex = 0
    }
}
