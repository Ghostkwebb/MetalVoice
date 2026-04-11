import Foundation
import Accelerate
import CoreML

class DeepFilterNetDSP {
    // Constants
    let sampleRate: Float = 48000.0
    let frameSize: Int = 960
    let hopSize: Int = 480
    let fftSize: Int = 960
    let binCount: Int = 481 // 960/2 + 1
    
    // FFT Setup
    private var fftSetup: vDSP_DFT_Setup?
    private var fftSetupInv: vDSP_DFT_Setup?
    
    // Buffers for STFT
    private var inputBuffer: [Float] = [] // Accumulate input
    private var outputBuffer: [Float] = [] // Accumulate output (Overlap-Add)
    
    // Processing Buffers
    private var window: [Float]
    private var realIn: [Float]
    private var imaginaryIn: [Float]
    private var realOut: [Float]
    private var imaginaryOut: [Float]
    
    // AI Model
    private var model: DeepFilterNet3_Streaming?
    private var isModelLoaded = false
    
    // Normalizers
    private var erbNorm: MeanSubNormalizer?
    private var specNorm: UnitMagNormalizer?
    private var featSpecNorm: UnitMagNormalizer?
    
    // Standard Mean Mean Subtraction (Robust to Variance Explosion)
    class MeanSubNormalizer {
        var mean: [Float]
        let alpha: Float
        let count: Int
        
        init(count: Int, alpha: Float = 0.99) {
            self.count = count
            self.alpha = alpha
            self.mean = [Float](repeating: 0, count: count)
        }
        
        func normalize(_ input: inout [Float], update: Bool) {
            for i in 0..<count {
                let x = input[i]
                if update {
                    mean[i] = alpha * mean[i] + (1 - alpha) * x
                }
                input[i] = x - mean[i]
            }
        }
    }
    
    // Unit Magnitude Normalizer (Lowered Floor for Quiet Speech)
    class UnitMagNormalizer {
        var magMean: [Float]
        let alpha: Float
        let minMean: Float
        let count: Int 
        
        init(count: Int, alpha: Float = 0.99, minMean: Float = 1e-4) {
            self.count = count
            self.alpha = alpha
            self.minMean = minMean
            self.magMean = [Float](repeating: 1.0, count: count) 
        }
        
        // Input: [Real0, Imag0, Real1, Imag1...]
        func normalize(_ input: inout [Float], update: Bool) {
            for i in 0..<count {
                let r = input[i*2]
                let im = input[i*2+1]
                let mag = sqrt(r*r + im*im)
                
                if update {
                    magMean[i] = alpha * magMean[i] + (1 - alpha) * mag
                }
                
                // Scale Factor
                let denominator = max(magMean[i], minMean)
                let scale = 1.0 / denominator
                
                input[i*2] *= scale
                input[i*2+1] *= scale
            }
        }
    }
    
    // Hidden State STORAGE (Flat Float Buffers)
    private var h_enc_buf: [Float]
    private var h_erb_buf: [Float]
    private var h_df_buf: [Float]
    
    // Debug Counter
    private var frameCount: Int = 0
    
    // Feature Buffers (History 10)
    // We use flat arrays for simplicity in handling shifts
    // shape: [10, 481, 2] -> 10 * 481 * 2 = 9620
    private var specHistory: [Float] = [Float](repeating: 0, count: 9620)
    
    // shape: [10, 32] -> 320
    private var erbHistory: [Float] = [Float](repeating: 0, count: 320)
    
    // shape: [10, 96, 2] -> 1920
    private var featSpecHistory: [Float] = [Float](repeating: 0, count: 1920)
    
    // ERB Matrix [32, 481]
    private var erbFilterbank: [Float] = []
    
    // Parameters
    public var outputGain: Float = 1.0 // User adjustable gain
    
    // OLA Accumulator (Strict Alignment)
    private var olaBuffer: [Float] = []
    
    init() {
        // Init State Buffers (Zero)
        h_enc_buf = [Float](repeating: 0, count: 256)
        h_erb_buf = [Float](repeating: 0, count: 2 * 256)
        h_df_buf = [Float](repeating: 0, count: 2 * 256)
        
        // Setup FFT (DFT for simplicity with sizes, though FFT is faster, DFT is 960 compatible easily)
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(frameSize), vDSP_DFT_Direction.FORWARD)
        fftSetupInv = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(frameSize), vDSP_DFT_Direction.INVERSE)
        
        // Window (Sqrt-Hann for Analysis/Synthesis pair)
        window = [Float](repeating: 0, count: frameSize)
        vDSP_hann_window(&window, vDSP_Length(frameSize), Int32(vDSP_HANN_DENORM))
        // Apply Sqrt
        var n = Int32(frameSize)
        vvsqrtf(&window, window, &n)
        
        // Allocate Scratch (Must be before method calls)
        realIn = [Float](repeating: 0, count: frameSize)
        imaginaryIn = [Float](repeating: 0, count: frameSize)
        realOut = [Float](repeating: 0, count: frameSize)
        imaginaryOut = [Float](repeating: 0, count: frameSize)
        
        // Init ERB Filters
        initFilterbank()
        
        // Init OLA Buffer
        olaBuffer = [Float](repeating: 0, count: frameSize)
        
        // Init Normalizers
        erbNorm = MeanSubNormalizer(count: 32)
        specNorm = UnitMagNormalizer(count: 481)
        featSpecNorm = UnitMagNormalizer(count: 96)
        
        // Load Model
        Task {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all // Use Neural Engine
                self.model = try await DeepFilterNet3_Streaming.load(configuration: config)
                self.initHiddenStates()
                self.isModelLoaded = true
                print("DSP: DFN3 Model Loaded")
            } catch {
                print("DSP: Model Load Error: \(error)")
            }
        }
    }
    
    deinit {
        if let setup = fftSetup { vDSP_DFT_DestroySetup(setup) }
        if let setupInv = fftSetupInv { vDSP_DFT_DestroySetup(setupInv) }
    }
    
    func initFilterbank() {
        // Create 32 triangular filters spaced on ERB scale
        erbFilterbank = [Float](repeating: 0, count: 32 * 481)
        
        let numBands = 32
        let minFreq: Float = 100.0
        let maxFreq: Float = sampleRate / 2.0
        
        // ERB Function
        func erb(_ f: Float) -> Float { return 24.7 * (4.37 * f / 1000.0 + 1.0) }
        func freqToErb(_ f: Float) -> Float { return 21.4 * log10(4.37 * f / 1000.0 + 1.0) }
        func erbToFreq(_ e: Float) -> Float { return 1000.0 / 4.37 * (pow(10.0, e / 21.4) - 1.0) }
        
        let minErb = freqToErb(minFreq)
        let maxErb = freqToErb(maxFreq)
        
        for b in 0..<numBands {
            let centerErb = minErb + (Float(b) * (maxErb - minErb) / Float(numBands + 1))
            let centerFreq = erbToFreq(centerErb)
            
            let prevCenter = (b == 0) ? minErb : (minErb + (Float(b-1) * (maxErb - minErb) / Float(numBands + 1)))
            let nextCenter = (b == numBands-1) ? maxErb : (minErb + (Float(b+1) * (maxErb - minErb) / Float(numBands + 1))) // Bug fix: +1
            
            let freqL = erbToFreq(prevCenter)
            let freqR = erbToFreq(nextCenter)
            
            // Map to Bins
            let binCenter = centerFreq / (sampleRate / Float(fftSize))
            let binL = freqL / (sampleRate / Float(fftSize))
            let binR = freqR / (sampleRate / Float(fftSize))
            
            var bandSum: Float = 0
            
            // Fill Weights
            for k in 0..<481 {
                let fBin = Float(k)
                var weight: Float = 0.0
                
                if fBin >= binL && fBin <= binCenter {
                    let den = max(binCenter - binL, 0.001)
                    weight = (fBin - binL) / den
                } else if fBin > binCenter && fBin <= binR {
                    let den = max(binR - binCenter, 0.001)
                    weight = (binR - fBin) / den
                }
                
                if weight > 0 {
                    erbFilterbank[b * 481 + k] = weight
                    bandSum += weight
                }
            }
            
            // Failsafe for narrow bands
            if bandSum == 0 {
                let centerBin = Int(binCenter)
                if centerBin >= 0 && centerBin < 481 {
                    erbFilterbank[b * 481 + centerBin] = 1.0
                }
            }
        }
    }
    
    func initHiddenStates() {
        // No-op (handled in init)
    }
    
    // Main Process Block (called by Audio Thread)
    // Needs to be fast.
    func process(input: UnsafePointer<Float>, count: Int, output: UnsafeMutablePointer<Float>) {
        let newSamples = Array(UnsafeBufferPointer(start: input, count: count))
        inputBuffer.append(contentsOf: newSamples)
        
        // 2. Ensure Output Buffer has enough space (pad with silence if needed, though usually we produce as much as we consume)
        // We will pull from `outputBuffer`.
        
        while inputBuffer.count >= frameSize {
            let frameSlice = Array(inputBuffer[0..<frameSize])
            inputBuffer.removeFirst(hopSize)
            processHop(frame: frameSlice)
        }
        
        // 4. Fill Output
        if outputBuffer.count >= count {
            for i in 0..<count {
                output[i] = outputBuffer[i]
            }
            outputBuffer.removeFirst(count)
        } else {
            // Underrun (should not happen if latency logic works, but pad silence)
            let avail = outputBuffer.count
            for i in 0..<avail {
                output[i] = outputBuffer[i]
            }
            for i in avail..<count {
                output[i] = 0
            }
            outputBuffer.removeAll()
        }
    }
    
    private func processHop(frame: [Float]) {
        frameCount += 1
        
        // Analysis Window
        var windowedInput = frame
        vDSP_vmul(frame, 1, window, 1, &windowedInput, 1, vDSP_Length(frameSize))
        
        // FFT
        realIn = windowedInput 
        vDSP_vclr(&imaginaryIn, 1, vDSP_Length(frameSize))
        
        if let setup = fftSetup {
            vDSP_DFT_Execute(setup, &realIn, &imaginaryIn, &realOut, &imaginaryOut)
        }
        
        // 3. Feature Extraction
        
        // 3a. Magnitude Squared (Power Spec)
        var magSq = [Float](repeating: 0, count: 481)
        var mag = [Float](repeating: 0, count: 481)
        
        for i in 0..<481 {
            let r = realOut[i]
            let im = imaginaryOut[i]
            magSq[i] = (r * r) + (im * im)
            mag[i] = sqrt(magSq[i])
        }
        
        // Check Signal Presence (Gated Normalization to prevent Silence Adaptation)
        var energy: Float = 0
        vDSP_sve(magSq, 1, &energy, vDSP_Length(481))
        let shouldUpdateNorm = (energy / 481.0) > 1e-6
        
        // 3b. ERB Feature Extraction (Standard: Log10 -> Mean Sub)
        var erbFeat = [Float](repeating: 0, count: 32)
        cblas_sgemv(CblasRowMajor, CblasNoTrans, Int32(32), Int32(481), 1.0, erbFilterbank, Int32(481), magSq, 1, 0.0, &erbFeat, 1)
        
        for i in 0..<32 {
            // Log 10 (dB-like)
            erbFeat[i] = log10(erbFeat[i] + 1e-10)
        }
        // Adaptive Norm
        erbNorm?.normalize(&erbFeat, update: shouldUpdateNorm)
        
        // Update erbHistory (Shift)
        let erbChunk = 32
        if erbHistory.count >= erbChunk { erbHistory.removeFirst(erbChunk) }
        erbHistory.append(contentsOf: erbFeat)
        while erbHistory.count < 320 { erbHistory.insert(0, at: 0) }
        while erbHistory.count > 320 { erbHistory.removeFirst() }
        
        
        // 3c. Spec Feature Extraction (Adaptive)
        // We calculate Full Compressed Spec (481 bins) for history
        var fullCompressed = [Float](repeating: 0, count: 481 * 2)
        let epsilon: Float = 1e-10
        let compressP: Float = 0.6 // Correct DFN3 Value (Boosts Loudness vs 0.5)
        
        for i in 0..<481 {
            // Compressed Spec: Real/|Real|^(1-C)
            let m = mag[i]
            let scale = pow(m + epsilon, compressP - 1.0)
            fullCompressed[i*2] = realOut[i] * scale
            fullCompressed[i*2+1] = imaginaryOut[i] * scale
        }
        
        // Adaptive Norm
        specNorm?.normalize(&fullCompressed, update: shouldUpdateNorm)
        
        // Update specHistory
        let specChunk = 481 * 2
        if specHistory.count >= specChunk { specHistory.removeFirst(specChunk) }
        specHistory.append(contentsOf: fullCompressed)
        while specHistory.count < (10 * 481 * 2) { specHistory.insert(0, at: 0) }
        while specHistory.count > (10 * 481 * 2) { specHistory.removeFirst() }

        // Update featSpecHistory (First 96 bins of fullCompressed)
        let featChunk = 96 * 2
        let featSlice = Array(fullCompressed[0..<featChunk])
        
        if featSpecHistory.count >= featChunk { featSpecHistory.removeFirst(featChunk) }
        featSpecHistory.append(contentsOf: featSlice)
        while featSpecHistory.count < (10 * 96 * 2) { featSpecHistory.insert(0, at: 0) }
        while featSpecHistory.count > (10 * 96 * 2) { featSpecHistory.removeFirst() }
        
        
        // 4. Inference
        if isModelLoaded, let model = model {
            do {
                // Prepare Inputs (Deep Copy Local Inputs to avoid race conditions with model buffers)
                let specMulti = try MLMultiArray(shape: [1, 1, 10, 481, 2], dataType: .float32)
                let erbMulti = try MLMultiArray(shape: [1, 1, 10, 32], dataType: .float32)
                let featMulti = try MLMultiArray(shape: [1, 1, 10, 96, 2], dataType: .float32)
                let hEncMulti = try MLMultiArray(shape: [1, 1, 256], dataType: .float16)
                let hErbMulti = try MLMultiArray(shape: [1, 2, 256], dataType: .float16)
                let hDfMulti = try MLMultiArray(shape: [1, 2, 256], dataType: .float16)
                
                // Copy History
                specMulti.withUnsafeMutableBufferPointer(ofType: Float.self) { ptr, _ in
                    let c = min(ptr.count, specHistory.count)
                    for i in 0..<c { ptr[i] = specHistory[i] }
                }
                erbMulti.withUnsafeMutableBufferPointer(ofType: Float.self) { ptr, _ in
                    let c = min(ptr.count, erbHistory.count)
                    for i in 0..<c { ptr[i] = erbHistory[i] }
                }
                featMulti.withUnsafeMutableBufferPointer(ofType: Float.self) { ptr, _ in
                    let c = min(ptr.count, featSpecHistory.count)
                    for i in 0..<c { ptr[i] = featSpecHistory[i] }
                }
                
                // Copy States (Float -> Float16 via NSNumber for safety)
                for i in 0..<h_enc_buf.count { hEncMulti[i] = NSNumber(value: h_enc_buf[i]) }
                for i in 0..<h_erb_buf.count { hErbMulti[i] = NSNumber(value: h_erb_buf[i]) }
                for i in 0..<h_df_buf.count { hDfMulti[i] = NSNumber(value: h_df_buf[i]) }
                
                let input = DeepFilterNet3_StreamingInput(spec_buf: specMulti, feat_erb_buf: erbMulti, feat_spec_buf: featMulti, h_enc_in: hEncMulti, h_erb_in: hErbMulti, h_df_in: hDfMulti)
                
                let output = try model.prediction(input: input)
                
                // Copy Back States
                let oEnc = output.h_enc_out
                let oErb = output.h_erb_out
                let oDf = output.h_df_out
                
                // Check if buffers match size (Safety)
                if oEnc.count == h_enc_buf.count {
                    for i in 0..<h_enc_buf.count { h_enc_buf[i] = oEnc[i].floatValue }
                }
                if oErb.count == h_erb_buf.count {
                    for i in 0..<h_erb_buf.count { h_erb_buf[i] = oErb[i].floatValue }
                }
                if oDf.count == h_df_buf.count {
                    for i in 0..<h_df_buf.count { h_df_buf[i] = oDf[i].floatValue }
                }
                
                // Process Output Spec
                let enhanced = output.enhanced_spec
                let zero = NSNumber(value: 0)
                let one = NSNumber(value: 1)
                
                for i in 0..<481 {
                    let iNum = NSNumber(value: i)
                    // Enhanced is 5D [1,1,1,481,2] - Compressed Normalized Complex Spec
                    let valR = enhanced[[zero, zero, zero, iNum, zero] as [NSNumber]].floatValue
                    let valI = enhanced[[zero, zero, zero, iNum, one] as [NSNumber]].floatValue
                    
                    // 1. De-Normalize (Undo UnitMag)
                    let mean = specNorm?.magMean[i] ?? 1.0
                    let compR = valR * mean
                    let compI = valI * mean
                    
                    // 2. De-Compress (Undo 0.6 power)
                    let compMag = sqrt(compR*compR + compI*compI)
                    // Scale = Comp^((1/C) - 1)
                    
                    let decompExp = (1.0 / compressP) - 1.0
                    let decompScale = pow(compMag + 1e-10, decompExp)
                    
                    realOut[i] = compR * decompScale
                    imaginaryOut[i] = compI * decompScale
                }
                
                // Mirror for IFFT
                 for i in 1..<480 {
                     realOut[frameSize - i] = realOut[i]
                     imaginaryOut[frameSize - i] = -imaginaryOut[i]
                }
                
            } catch {
                print("DSP: Inference Error: \(error)")
            }
        }
        
        // 5. ISTFT
        var recoveredReal = [Float](repeating: 0, count: frameSize)
        var recoveredImag = [Float](repeating: 0, count: frameSize)
        
        if let invSetup = fftSetupInv {
             vDSP_DFT_Execute(invSetup, &realOut, &imaginaryOut, &recoveredReal, &recoveredImag)
        }
        
        // APPLY SYNTHESIS WINDOW (Smooths discontinuities causing Static/Robotic artifacts)
        vDSP_vmul(recoveredReal, 1, window, 1, &recoveredReal, 1, vDSP_Length(frameSize))
        
        // Scale 1/N * Gain
        var scale = (1.0 / Float(frameSize)) * outputGain
        vDSP_vsmul(recoveredReal, 1, &scale, &recoveredReal, 1, vDSP_Length(frameSize))
        
        // 6. Overlap Add (Strict Alignment for Phase Coherence)
        // Add recovered frame to OLA Accumulator
        vDSP_vadd(recoveredReal, 1, olaBuffer, 1, &olaBuffer, 1, vDSP_Length(frameSize))
        
        // Extract valid hop (Head) to Output Queue
        let readySamples = Array(olaBuffer[0..<hopSize])
        outputBuffer.append(contentsOf: readySamples)
        
        // Shift OLA state
        olaBuffer.removeFirst(hopSize)
        olaBuffer.append(contentsOf: [Float](repeating: 0, count: hopSize))
    }
}
