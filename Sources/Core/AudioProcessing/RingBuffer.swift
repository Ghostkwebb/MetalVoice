import Foundation
import os.lock

/// A simple, thread-safe circular buffer for Float audio samples.
class RingBuffer {
    private let buffer: UnsafeMutablePointer<Float>
    private let capacity: Int
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private var availableCount: Int = 0
    
    // Low-level lock for audio thread safety (better than Semaphore, faster than NSLock)
    private var lock = os_unfair_lock()
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
        self.buffer.initialize(repeating: 0.0, count: capacity)
    }
    
    deinit {
        buffer.deinitialize(count: capacity)
        buffer.deallocate()
    }
    
    func reset() {
        os_unfair_lock_lock(&lock)
        writeIndex = 0
        readIndex = 0
        availableCount = 0
        os_unfair_lock_unlock(&lock)
    }
    
    func write(_ data: UnsafePointer<Float>, count: Int) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        if availableCount + count > capacity {
            return false // Overflow
        }
        
        // Write split logic
        let firstChunk = min(count, capacity - writeIndex)
        let secondChunk = count - firstChunk
        
        // buffer + writeIndex
        (buffer + writeIndex).update(from: data, count: firstChunk)
        
        if secondChunk > 0 {
            buffer.update(from: data + firstChunk, count: secondChunk)
        }
        
        writeIndex = (writeIndex + count) % capacity
        availableCount += count
        
        return true
    }
    
    /// Reads `count` samples into `outData`. Returns false if not enough data.
    func read(into outData: UnsafeMutablePointer<Float>, count: Int) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        if availableCount < count {
            return false // Underflow
        }
        
        let firstChunk = min(count, capacity - readIndex)
        let secondChunk = count - firstChunk
        
        outData.update(from: buffer + readIndex, count: firstChunk)
        
        if secondChunk > 0 {
            (outData + firstChunk).update(from: buffer, count: secondChunk)
        }
        
        readIndex = (readIndex + count) % capacity
        availableCount -= count
        
        return true
    }
    
    var count: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return availableCount
    }
    
    /// Discards `count` samples from the read head to reduce latency
    func drop(_ count: Int) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        // Don't drop more than available
        let dropCount = min(count, availableCount)
        readIndex = (readIndex + dropCount) % capacity
        availableCount -= dropCount
    }
}
