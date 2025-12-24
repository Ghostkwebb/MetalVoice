import Foundation
import AVFoundation
import AVFAudio
import Combine
import AudioToolbox
import CoreAudio
import Accelerate

class AudioModel: NSObject, ObservableObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    // Published State for UI
    @Published var isAIEnabled: Bool = false {
        didSet {
        }
    }
    @Published var inputDevices: [AVCaptureDevice] = [] // Changed to AVCaptureDevice
    @Published var selectedInputDeviceID: String = "" { // IDs are Strings in AVCapture
        didSet {
             setupCaptureSession()
        }
    }
    @Published var errorMessage: String?
    @Published var inputLevel: Float = 0.0
    @Published var activeOutputDeviceName: String = "Unknown"
    @Published var permissionStatus: String = "Unknown"
    
    // Output Selection
    @Published var outputDevices: [DeviceStruct] = []
    @Published var selectedOutputDeviceID: AudioObjectID = 0 {
        didSet {
             setupPlaybackEngine()
        }
    }
    
    @Published var isPlayingTestTone: Bool = false {
        didSet {
            // No action needed, source node checks this flag
        }
    }
    
    @Published var outputGainValue: Float = 1.0 {
        didSet {
             dspEngine.outputGain = outputGainValue
        }
    }

    struct DeviceStruct: Identifiable {
        let id: AudioObjectID
        let name: String
    }
    
    // Capture (Input)
    private let captureSession = AVCaptureSession()
    private let captureOutput = AVCaptureAudioDataOutput()
    private let processingQueue = DispatchQueue(label: "audio.processing.queue", qos: .userInteractive)
    
    // Playback (Output)
    private let engine = AVAudioEngine()
    private var playbackSourceNode: AVAudioSourceNode! 
    private var outputNode: AVAudioOutputNode { engine.outputNode }
    private var mainMixer: AVAudioMixerNode { engine.mainMixerNode }
    
    // Buffering
    private let ringBuffer = RingBuffer(capacity: 48000 * 5)
    
    // Processing Modules
    // Processing Modules
    private let dspEngine = DeepFilterNetDSP()
    
    override init() {
        super.init()
        
        let bufferRef = ringBuffer
        let dsp = dspEngine
        
        playbackSourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let data = abl[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let count = Int(frameCount)
            
            // 1. Test Tone
            if let self = self, self.isPlayingTestTone {
                 for i in 0..<count {
                     data[i] = Float.random(in: -0.1...0.1) 
                 }
                 return noErr
            }
            
            // 2. Latency
            let latencyTarget = 2400
            let available = bufferRef.count
            if available > (latencyTarget + count) {
                bufferRef.drop(available - latencyTarget)
            }
            
            // 3. Read
            // DSP Engine needs contiguous flow. If we underflow, we feed silence.
            if !bufferRef.read(into: data, count: count) {
                AudioUtils.shared.fillSilence(data, count: count)
                return noErr
            }
            
            // 4. Processing
            
            // Gain (Boost Mic)
            var gain: Float = 1.0
            vDSP_vsmul(data, 1, &gain, data, 1, vDSP_Length(frameCount))
            
            if let self = self, self.isAIEnabled {
                // DSP STFT Pipeline
                dsp.process(input: data, count: count, output: data)
            }
            
            return noErr
        }
        
        checkPermissions()
        fetchInputDevices()
        fetchOutputDevices()
        setupCaptureSession()
        setupPlaybackEngine()
    }
    
    func fetchOutputDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        let deviceCount = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
        
        var newDevs: [DeviceStruct] = []
        
        for id in deviceIDs {
            // Check Output Channels
            let scope = kAudioObjectPropertyScopeOutput
            var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: scope, mElement: 0)
            var size: UInt32 = 0
            AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size)
            if size > 0 {
                var nameSize = UInt32(MemoryLayout<CFString?>.size)
                var namePtr: Unmanaged<CFString>?
                var nameAddr = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
                AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, &namePtr)
                if let cf = namePtr?.takeRetainedValue() {
                    newDevs.append(DeviceStruct(id: id, name: cf as String))
                }
            }
        }
        
        DispatchQueue.main.async {
            self.outputDevices = newDevs
            // Default to BlackHole if exists
            if let bh = newDevs.first(where: { $0.name.contains("BlackHole") }) {
                self.selectedOutputDeviceID = bh.id
            } else if let first = newDevs.first {
                self.selectedOutputDeviceID = first.id
            }
        }
    }
    
    // ... input methods ...
    
    func setupPlaybackEngine() {
        engine.stop()
        engine.reset()
        
        // Output Device
        if selectedOutputDeviceID != 0 {
             var deviceID = selectedOutputDeviceID
             let size = UInt32(MemoryLayout<AudioObjectID>.size)
             AudioUnitSetProperty(outputNode.audioUnit!,
                                  kAudioOutputUnitProperty_CurrentDevice,
                                  kAudioUnitScope_Global,
                                  0,
                                  &deviceID,
                                  size)
             
             // Update Name
             if let dev = outputDevices.first(where: { $0.id == selectedOutputDeviceID }) {
                 DispatchQueue.main.async { self.activeOutputDeviceName = dev.name }
             }
        }

        // Attach Source
        engine.attach(playbackSourceNode)
        
        // Connect
        engine.connect(playbackSourceNode, to: mainMixer, format: AudioUtils.shared.processingFormat)
        engine.connect(mainMixer, to: outputNode, format: nil)
        
        do {
            try engine.start()
        } catch {
            print("Engine Error: \(error)")
        }
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: permissionStatus = "Authorized"
        case .denied: permissionStatus = "Denied"
        case .restricted: permissionStatus = "Restricted"
        case .notDetermined:
            permissionStatus = "Not Determined"
            AVCaptureDevice.requestAccess(for: .audio) { g in
                DispatchQueue.main.async { self.permissionStatus = g ? "Authorized" : "Denied" }
            }
        @unknown default: permissionStatus = "Unknown"
        }
    }
    
    func fetchInputDevices() {
        // AVCaptureDeviceDiscovery
        let types: [AVCaptureDevice.DeviceType] = [.builtInMicrophone, .externalUnknown] // .externalUnknown covers USB mics usually
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .audio, position: .unspecified)
        // Note: AVCaptureDevice doesn't easily show "Loopback" devices like BlackHole.
        // But for "Microphone" input, that is what we want.
        
        var devs = session.devices
        // Sort: Built-in first?
        devs.sort { $0.localizedName < $1.localizedName }
        
        DispatchQueue.main.async {
            self.inputDevices = devs
            if let defaultDev = AVCaptureDevice.default(for: .audio) {
                 self.selectedInputDeviceID = defaultDev.uniqueID
            } else if let first = devs.first {
                self.selectedInputDeviceID = first.uniqueID
            }
        }
    }
    
    func setupCaptureSession() {
        captureSession.stopRunning()
        captureSession.beginConfiguration()
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }
        
        do {
            guard let device = AVCaptureDevice(uniqueID: selectedInputDeviceID) else {
                print("Device not found: \(selectedInputDeviceID)")
                captureSession.commitConfiguration()
                return
            }
            
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            if captureSession.canAddOutput(captureOutput) {
                captureSession.addOutput(captureOutput)
                captureOutput.setSampleBufferDelegate(self, queue: processingQueue)
            }
            
        } catch {
            print("Capture Setup Error: \(error)")
        }
        
        captureSession.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    
    private var PermissionCheckOnce = false
    
    // Converter State
    private var inputConverter: AVAudioConverter?
    private var inputPCMBuffer: AVAudioPCMBuffer?
    private var inputBuffer48k: AVAudioPCMBuffer?
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Reset converter to prevent EndOfStream state lockout from previous frame
        inputConverter?.reset()
        
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        // Use AudioStreamBasicDescription to create AVAudioFormat
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else { return }
        
        // 1. Determine Input Format
        guard let inputFormat = AVAudioFormat(streamDescription: asbd) else { return }
        
        // 2. Define Target Format (48kHz, Float32, Mono)
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000.0, channels: 1, interleaved: false) else { return }
        
        // 3. Setup Converter if needed
        if inputConverter == nil || inputConverter?.inputFormat != inputFormat {
             print("AudioModel: Initializing Converter \(inputFormat.sampleRate) -> 48000")
             inputConverter = AVAudioConverter(from: inputFormat, to: targetFormat)
            
             // Create Buffers
             let maxInputFrames = AVAudioFrameCount(4096)
             inputPCMBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: maxInputFrames)
            
             let ratio = targetFormat.sampleRate / inputFormat.sampleRate
             let maxOutputFrames = AVAudioFrameCount(Double(maxInputFrames) * ratio + 5)
             inputBuffer48k = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: maxOutputFrames)
        }
        
        guard let converter = inputConverter,
              let inputBuffer = inputPCMBuffer,
              let outputBuffer = inputBuffer48k else { return }
              
        // 4. Extract AudioBufferList from CMSampleBuffer
        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
        
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        guard status == noErr else { return }
        
        // 5. Copy Data to InputPCMBuffer
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        inputBuffer.frameLength = AVAudioFrameCount(numSamples)
        
        // Use UnsafeMutableAudioBufferListPointer for safe iteration
        let srcPtr = UnsafeMutableAudioBufferListPointer(&audioBufferList)
        let dstPtr = UnsafeMutableAudioBufferListPointer(inputBuffer.mutableAudioBufferList)
        
        let buffersToCheck = min(srcPtr.count, dstPtr.count)
        
        for i in 0..<buffersToCheck {
            let src = srcPtr[i]
            let dst = dstPtr[i]
            
            if dst.mDataByteSize >= src.mDataByteSize {
                memcpy(dst.mData, src.mData, Int(src.mDataByteSize))
            }
        }
        
        // 6. Convert
        var error: NSError? = nil
        
        // Input Block
        var haveFed = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
           if !haveFed {
               outStatus.pointee = .haveData
               haveFed = true
               return inputBuffer
           } else {
               outStatus.pointee = .endOfStream
               return nil
           }
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        // 7. Write to Ring Buffer
        let convertedFrames = Int(outputBuffer.frameLength)
        
        if convertedFrames > 0, let floatData = outputBuffer.floatChannelData?[0] {
             // Metering (RMS)
             var sum: Float = 0
             // Sample every 4th visual
             for i in stride(from: 0, to: min(convertedFrames, 256), by: 4) {
                 sum += floatData[i] * floatData[i]
             }
             if convertedFrames > 0 {
                 let rms = sqrt(sum / Float(min(convertedFrames, 256)/4 + 1))
                 DispatchQueue.main.async { self.inputLevel = rms }
             }
             
             // Push 48k Float32 to RingBuffer
             _ = self.ringBuffer.write(floatData, count: convertedFrames)
        }
    }
}
