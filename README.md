# MetalVoice 🎙️

**MetalVoice** is a macOS menu bar application that uses AI (DeepFilterNet) to remove background noise and room reverb from your microphone in real-time. Built with Swift, Metal Performance Shaders, and CoreML.

<p align="center">
  <img src="Resources/MetalVoiceLogo.png" width="128" height="128" alt="MetalVoice Logo">
</p>

## Features ✨

*   **Real-time Noise Suppression**: Removes fans, typing, loud clicks, and background chatter.
*   **De-Reverberation**: Reduces room echo for a studio-quality sound.
*   **Low Latency**: Optimized for real-time communication (~20-40ms latency).
*   **Privacy First**: All processing happens **on-device** using the Apple Neural Engine. No audio ever leaves your Mac.
*   **Lightweight**: Runs unobtrusively in your menu bar.
*   **Universal Support**: Works with any input device (USB mics, Built-in mics) and outputs to Virtual Cables (BlackHole, VB-Cable).

## Installation 📥

1.  Download the latest release from the [Releases Page](../../releases).
2.  Unzip `MetalVoice_v1.0.zip`.
3.  Drag `MetalVoice.app` to your **Applications** folder.
4.  Right-click and select **Open** (to bypass Gatekeeper if unsigned).

## Usage 🛠️

1.  **Launch MetalVoice**: You will see a waveform icon 🌊 in your menu bar.
2.  **Open Settings**: Click the gear icon inside the menu.
3.  **Select Microphone**: Choose your physical microphone as the **Input Device**.
4.  **Select Output**: Choose a virtual audio driver like **BlackHole 2ch** (Recommended) or VB-Cable as the **Output Device**.
5.  **Configure Chat Apps**: In Discord, Zoom, or OBS, set your Input Device to the **same virtual cable** (e.g., "BlackHole 2ch").
6.  **Enable AI**: Toggle the switch to **ON**. Your voice is now enhanced! 🚀

> **Note**: If you don't have BlackHole installed, you can get it [here](https://github.com/ExistentialAudio/BlackHole) or via Homebrew (`brew install blackhole-2ch`).

## Tech Stack 💻

*   **Language**: Swift 5
*   **UI**: SwiftUI (macOS)
*   **Audio Engine**: AVFoundation & Accelerate (vDSP)
*   **AI Model**: [DeepFilterNet3](https://github.com/Rikorose/DeepFilterNet) (Converted to CoreML)
*   **Inference**: CoreML + Metal Performance Shaders

## Credits 🙏

*   **DeepFilterNet**: The incredible noise suppression model is created by [Hendrik Schröter (Rikorose)](https://github.com/Rikorose). This app uses a CoreML conversion of the DeepFilterNet3 model.
*   **Accelerate Framework**: For efficient DSP (FFT, Windowing).

## License 📄

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
The DeepFilterNet model weights are used under their respective license (MIT/Apache 2.0).
