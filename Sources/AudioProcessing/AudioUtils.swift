import AVFoundation
import Accelerate

class AudioUtils {
    static let shared = AudioUtils()
    
    // Default format for MetalVoice internal processing
    // 48kHz, Float32, Non-Interleaved (Planar) is standard for AVAudioEngine
    let processingFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
    
    /// Converts a buffer to the target format if needed. Returns nil if conversion fails
    func convert(buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format == format {
            return buffer
        }
        
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            print("Failed to create converter")
            return nil
        }
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: convertFrameCapacity(buffer.frameLength, from: buffer.format, to: format)) else {
            return nil
        }
        
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { packetCount, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        if status == .error || error != nil {
            print("Conversion error: \(String(describing: error))")
            return nil
        }
        
        return outputBuffer
    }
    
    private func convertFrameCapacity(_ count: AVAudioFrameCount, from: AVAudioFormat, to: AVAudioFormat) -> AVAudioFrameCount {
        let ratio = to.sampleRate / from.sampleRate
        return AVAudioFrameCount(Double(count) * ratio)
    }
    
    /// Simple utility to fill a float buffer with silence
    func fillSilence(_ buffer: UnsafeMutablePointer<Float>, count: Int) {
        vDSP_vclr(buffer, 1, vDSP_Length(count))
    }
    
    /// Simple utility to copy buffer
    func copy(_ src: UnsafePointer<Float>, to dst: UnsafeMutablePointer<Float>, count: Int) {
        cblas_scopy(Int32(count), src, 1, dst, 1)
    }
}
