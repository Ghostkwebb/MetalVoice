# ULTIMATE METALVOICE PROJECT CONTEXT FOR AI AGENTS

**CRITICAL WARNING TO ALL FUTURE AI AGENTS READING THIS FILE:**
This file contains the absolute ground truth for the `MetalVoice` repository. Do not make assumptions about standard macOS Audio programming. The architecture here relies on tight workarounds to achieve zero-latency CoreML `.all` (Neural Engine) processing while bridging `AVCaptureSession` and `AVAudioEngine`.

---

## 1. PROJECT SCOPE & HARDWARE CONSTRAINTS
- **Target OS:** macOS 13.0+
- **Architecture:** Apple Silicon (arm64) ONLY. Intel Macs will fail to compile or crash due to hard dependencies on `CoreML` operations tuned specifically for the Apple Neural Engine/Metal Performance Shaders.
- **Goal:** Real-time DeepFilterNet3 noise suppression. 48kHz, mono in, 48kHz mono out.

## 2. DIRECTORY & BUILD SYSTEM (SPM + SHELL)
This project **DOES NOT USE XCODE (`.xcodeproj`)**. It is pure Swift Package Manager.
- **`Package.swift` Targets:**
  - `Core`: Static library (`Sources/Core`). Contains all ML models, DSP math, and Audio Engines.
  - `MetalVoice`: GUI App (`Sources/App`). Depends on `Core`.
  - `MetalVoiceCLI`: Terminal App (`Sources/CLI`). Depends on `Core`.
- **The Bundle/Release Workflow (`bundle.sh`):**
  - SPM executables cannot securely request macOS Microphone access (`NSMicrophoneUsageDescription`) without proper bundling and code signing. 
  - `bundle.sh` runs `swift build -c release`, physically creates `MetalVoice.app/Contents/MacOS` and `.../Resources`, copies the binary/Info.plist, and runs `codesign --force --deep --sign - --entitlements "Resources/MetalVoice.entitlements" "$APP_BUNDLE"`.
  - **WARNING:** Do not run the `.build/debug/MetalVoice` binary directly for GUI work. It will instantly crash upon microphone permission request. You MUST run `./bundle.sh` and then `open MetalVoice.app`.

## 3. COREML & BUNDLE RESOLUTION (THE DEEPFILTERNET HACK)
**File:** `Sources/Core/AudioProcessing/DeepFilterNet3_Streaming.swift`
- The `DeepFilterNet3_Streaming.mlmodelc` is NOT embedded cleanly via SPM's `Bundle.module` because SPM inconsistently handles `.mlmodelc` directories depending on whether the target is an executable or a library.
- To solve this for BOTH the GUI and CLI, `urlOfModelInThisBundle` was manually overridden to check three locations:
  1. `Bundle.main.url` (Standard fallback)
  2. `Bundle(for: self).url` (Static library resolution)
  3. **The CLI Distributed Fallback:** `Bundle.main.bundleURL.appendingPathComponent("MetalVoice.app/Contents/Resources/DeepFilterNet3_Streaming.mlmodelc")`. Because the release ZIP puts `MetalVoiceCLI` directly next to `MetalVoice.app`, the CLI peeks *into* the GUI app's bundle to load the heavy ML weights without having to duplicate the 20MB model.
- **DO NOT TOUCH** `urlOfModelInThisBundle` unless you know exactly what you are doing.

## 4. AUDIO GRAPH & SYNCHRONIZATION (THE BIGGEST BOTTLENECK)
**File:** `Sources/Core/AudioModel.swift`
- **Input:** `AVCaptureSession` -> `AVCaptureAudioDataOutput`.
  - Why not `AVAudioEngine` input node? Because macOS system microphones and virtual loopbacks constantly drop frames or fail to map properly to AVAudioEngine's input format without aggressive resampling issues. `AVCaptureSession` handles device hotswapping and aggregate devices far better.
- **Converter:** `AVAudioConverter` converts whatever variable format the mic gives into exactly: `pcmFormatFloat32, 48000.0 Hz, 1 channel, interleaved: false`. This happens inside `captureOutput()`.
- **The Bridge:** `RingBuffer.swift`
  - Audio arrives asynchronously on a background queue from `AVCaptureSession`. It writes exactly `convertedFrames` into the `RingBuffer`.
  - Audio is pulled synchronously by `AVAudioSourceNode` on the high-thread-priority CoreAudio render thread.
- **Latency Management (LINES 88-94):**
  ```swift
  let latencyTarget = 2400 // 50ms at 48kHz
  let available = bufferRef.count
  if available > (latencyTarget + count) {
      bufferRef.drop(available - latencyTarget)
  }
  ```
  If the input thread outpaces the output thread by more than 50ms, it drops audio to prevent creeping latency over long Discord calls. Do not increase this arbitrarily or latency will suffer.

## 5. DSP PIPELINE & DEEPFILTERNET MATH
**File:** `Sources/Core/AudioProcessing/DeepFilterNetDSP.swift`
- The model takes in STFT frames and outputs STFT frames. It requires Overlap-Add (OLA) processing.
- **FFT Size:** 960 (480 bins + 1 DC). At 48kHz, this is exactly 20ms per frame.
- **Hop Size:** 480 (10ms).
- **Buffer Flow:** `process()` takes N samples -> splits them into 480-sample hops -> pushes to `inputBuffer` -> if `inputBuffer` >= 960, runs `processHop()` -> pushes to `outputBuffer` -> pops N samples out.
- **Normalization (CRITICAL RECENT BUG FIX):**
  - Background: When humans speak quietly, the DSP tends to over-suppress, causing words to sound muffled or robotic.
  - Fix implemented in `UnitMagNormalizer.swift` (inside the DSP file): `minMean` was lowered from `1e-5` to `1e-4`, and the `alpha` value was symmetrically stabilized to `0.99`. This ensures the energy history decays smoothly. 
  - **If the user complains about muffled audio, check the STFT normalization constants first!**

## 6. THREADING, UI, AND STATE
- **`AudioModel`** conforms to `ObservableObject`. All exposed `@Published` variables (`isAIEnabled`, `inputLevel`, `selectedInputDeviceID`, etc.) must be mutated on `DispatchQueue.main.async`. If you violate this, SwiftUI will throw a runtime exception.
- **`setupPlaybackEngine()`** dispatches to a serial `engineQueue` to avoid main-thread stalls when starting `AVAudioEngine` on virtual devices (e.g. BlackHole). `@Published` values are captured *before* the dispatch to avoid data races.
- **UserDefaults Persistence:** Input device UID, output device UID, AI toggle, and output gain are persisted via `UserDefaults`. An `isRestoringDefaults` guard prevents fallback device selection from overwriting the user's saved preference.
- Permissions: `checkPermissions()` handles `AVCaptureDevice.authorizationStatus`. Keep this updated if Apple modifies Privacy prompts in future macOS versions.

## 7. CLI PIPELINE RULES
**File:** `Sources/CLI/main.swift`
- The user requested the ability to run 2 distinct independent audio graphs. E.g., Clean their mic for a Zoom meeting, AND clean the incoming Zoom meeting audio for their headphones.
- Because `CoreML` (`DeepFilterNet`) is single-threaded inside an app without complex instance management, the safest architecture is completely separate binaries. 
- The `MetalVoiceCLI` binary parses args (`--in`, `--out`, `--gain`), initializes identical DSP logic, and runs `RunLoop.main.run()` to stay alive without UI. 
- It communicates cleanly and prints errors before exit.

## 8. DEPLOYMENT & GITHUB RELEASES
- The user's `.gitignore` completely ignores `*.mlmodelc` and `*.mlpackage`. If you must upgrade the AI model weights natively via `export_coreml.py` (which is currently missing/deleted from the repo), you MUST force add them `git add -f` or advise the user to remove the ignore rules.
- The `bundle.sh` script executes CLI generation, copies everything, and expects the user to zip the output manually (or uses the script `zip -r MetalVoice_v1.2.zip MetalVoice.app MetalVoiceCLI`).

## 9. RECENT WORK & CHANGELOG (v1.0 -> v1.2)
- **Codebase Split:** Refactored the raw structure into a multi-target SPM project (`Sources/Core`, `Sources/App`, and `Sources/CLI`).
- **CLI Implementation (`MetalVoiceCLI`):** Built a standalone headless terminal binary to execute dual-pipelines for advanced users (e.g., suppressing a local mic AND incoming meeting audio simultaneously).
- **Model Bundle Fix:** Solved SPM resource synthesis failures by adding dynamic bundle fallback resolution. `MetalVoiceCLI` correctly loads `DeepFilterNet3_Streaming.mlmodelc` from inside the adjacent `MetalVoice.app/Contents/Resources` bundle when distributed via ZIP.
- **UI & Release:** Bumped hardcoded settings versions to `v1.2`, rewrote `README.md` adding CLI tutorials.
- **Virtual Device Fix:** Swapped `CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer` for `CMSampleBufferCopyPCMDataIntoAudioBufferList` to support multi-channel Non-Interleaved virtual cables (BlackHole/Loopback). Replaced `.endOfStream`/`reset()` loop with continuous `.noDataNow` to fix sample rate conversion stalls.
- **v1.2 — Persist Device + AI Selection (PR #4 by @Baltsat):** Input/output device UIDs, AI toggle, and output gain now persist via `UserDefaults` across launches. Output device uses stable CoreAudio `kAudioDevicePropertyDeviceUID` (not volatile `AudioObjectID`). Fallback chain: saved → BlackHole → first available.
- **v1.2 — Engine Off Main Thread (PR #4):** `setupPlaybackEngine()` now runs on a serial `engineQueue` to prevent main-thread stalls when starting `AVAudioEngine` on virtual output devices. `@Published` values captured before dispatch to avoid data races.
- **v1.2 — DSP Hot Path Optimization (PR #4):** Preallocated 6 reusable `MLMultiArray` input buffers (eliminates ~600 allocs/sec). Hidden state input writes use direct `Float16` buffer on macOS 15+ with NSNumber fallback on 13-14. Output reads remain stride-safe subscript access (CoreML output strides may vary by compute unit).
- **v1.2 — Float16 Availability Fix:** Wrapped `withUnsafeMutableBufferPointer(ofType: Float16.self)` in `#available(macOS 15.0, *)` check. Falls back to `NSNumber` subscript on macOS 13-14 to prevent runtime crash.

---
**SUMMARY:** MetalVoice is a tightly wound, highly-optimized wrapper around Apple's audio frameworks and CoreML. Do not rewrite working DSP components, treat the RingBuffer carefully, respect the SPM `Bundle` idiosyncrasies, and test permissions via `bundle.sh` and never directly via bare executables unless using the CLI. Output reads from CoreML must use stride-safe subscript access — flat buffer indexing on Neural Engine outputs causes phase corruption. You are fully briefed. Proceed.
