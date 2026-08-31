import Foundation
import AVFoundation
import Darwin
import Core

let version = UpdateChecker.currentVersion

// Terminal controller for raw mode & clean restoration
class TerminalController {
    static let shared = TerminalController()
    private var origTermios = termios()
    private(set) var isRaw = false
    let isTTY: Bool
    
    init() {
        self.isTTY = isatty(STDOUT_FILENO) != 0 && isatty(STDIN_FILENO) != 0
    }
    
    func enableRawMode() {
        guard isTTY && !isRaw else { return }
        tcgetattr(STDIN_FILENO, &origTermios)
        var raw = origTermios
        raw.c_lflag &= ~(UInt(ECHO | ICANON)) // Disable echo and canonical line buffering
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        print("\u{001B}[?25l", terminator: "") // Hide cursor
        fflush(stdout)
        isRaw = true
    }
    
    func restore() {
        guard isRaw else { return }
        var orig = origTermios
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig)
        print("\u{001B}[?25h\u{001B}[0m") // Show cursor, reset color styling
        fflush(stdout)
        isRaw = false
    }
    
    func getWidth() -> Int {
        var w = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0 && w.ws_col > 30 {
            return Int(w.ws_col)
        }
        return 80
    }
}

// Ensure terminal styling is restored on unexpected exit
signal(SIGINT) { _ in
    TerminalController.shared.restore()
    print("\nExiting MetalVoice CLI. Goodbye! 👋\n")
    exit(0)
}
signal(SIGTERM) { _ in
    TerminalController.shared.restore()
    exit(0)
}
atexit {
    TerminalController.shared.restore()
}

// Basic Arg Parsing
var inputName: String?
var outputName: String?
var gain: Float = 1.0
var aiEnabled: Bool = true
var testTone: Bool = false
var shouldCheckUpdate = false
var shouldPerformUpdate = false
var scrollingLogMode = false

var args = CommandLine.arguments
var i = 1
while i < args.count {
    switch args[i] {
    case "--in":
        if i + 1 < args.count { inputName = args[i + 1]; i += 1 }
    case "--out":
        if i + 1 < args.count { outputName = args[i + 1]; i += 1 }
    case "--gain":
        if i + 1 < args.count, let g = Float(args[i + 1]) { gain = g; i += 1 }
    case "--ai":
        if i + 1 < args.count {
            aiEnabled = (args[i + 1].lowercased() != "false" && args[i + 1] != "0")
            i += 1
        }
    case "--tone":
        testTone = true
    case "--log", "--scroll":
        scrollingLogMode = true
    case "--check-update":
        shouldCheckUpdate = true
    case "--update":
        shouldPerformUpdate = true
    case "--version", "-v":
        print("MetalVoice version \(version)")
        exit(0)
    case "--help", "-h":
        print("""
        MetalVoice CLI 🎙️ (v\(version))
        Usage: MetalVoiceCLI [options]
        
        Options:
          --in <name>         Input microphone name (e.g. "MacBook Pro Microphone", "USB AUDIO")
          --out <name>        Output device name (e.g. "BlackHole 2ch", "LitLink Audio Bridge")
          --gain <float>      Output gain multiplier (default: 1.0)
          --ai <true|false>   Enable/disable DeepFilterNet AI noise reduction (default: true)
          --tone              Generate synthetic test tone to test output path without microphone
          --log, --scroll     Enable scrolling log mode instead of in-place dashboard
          --check-update      Check for new releases on GitHub
          --update            Download and install the latest release of MetalVoiceCLI
          --version, -v       Show version
          --help, -h          Show this help message
        
        Interactive Controls:
          [Q] Quit   [A] Toggle AI   [T] Toggle Tone   [+/-] Gain   [H] Toggle Log History
        """)
        exit(0)
    default:
        break
    }
    i += 1
}

// Handle --check-update
if shouldCheckUpdate {
    print("Checking for updates...")
    let sema = DispatchSemaphore(value: 0)
    UpdateChecker.shared.checkForUpdates { result in
        switch result {
        case .success(let release):
            if release.isNewer {
                print("✨ A new version is available: \(release.tagName) (Current: v\(version))")
                print("   Release URL: \(release.htmlURL)")
                print("   To update CLI automatically, run: MetalVoiceCLI --update")
            } else {
                print("✅ MetalVoice is up to date (v\(version)).")
            }
        case .failure(let error):
            print("❌ Failed to check for updates: \(error.localizedDescription)")
        }
        sema.signal()
    }
    sema.wait()
    exit(0)
}

// Handle --update
if shouldPerformUpdate {
    print("Checking for latest release...")
    let sema = DispatchSemaphore(value: 0)
    UpdateChecker.shared.checkForUpdates { result in
        switch result {
        case .success(let release):
            guard let downloadURL = release.downloadURL else {
                print("❌ No release download package (.zip) found for \(release.tagName)")
                sema.signal()
                return
            }
            if !release.isNewer {
                print("ℹ️ You already have the latest version (v\(version)). Re-installing \(release.tagName)...")
            } else {
                print("⬇️ Downloading \(release.tagName)...")
            }
            
            let execPath = CommandLine.arguments[0]
            let resolvedExecPath = URL(fileURLWithPath: execPath).resolvingSymlinksInPath().path
            
            UpdateChecker.updateCLIBinary(downloadURL: downloadURL, currentExecutablePath: resolvedExecPath) { updateResult in
                switch updateResult {
                case .success(let msg):
                    print("✅ \(msg)")
                case .failure(let err):
                    print("❌ Update failed: \(err.localizedDescription)")
                    print("   You can download the update manually from: \(release.htmlURL)")
                }
                sema.signal()
            }
        case .failure(let error):
            print("❌ Failed to fetch release info: \(error.localizedDescription)")
            sema.signal()
        }
    }
    sema.wait()
    exit(0)
}

print("MetalVoice CLI 🎙️ (v\(version))")

let model = AudioModel()
var updateReleaseInfo: ReleaseInfo? = nil

// Non-blocking background check for updates on startup
UpdateChecker.shared.checkForUpdates { result in
    if case .success(let release) = result, release.isNewer {
        updateReleaseInfo = release
    }
}

// Wait for device discovery
RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))

// --- Device Selection (Interactive or Flag-Based) ---

// 1. Input Device Selection
if let inName = inputName {
    if let inDev = model.inputDevices.first(where: { $0.localizedName.localizedCaseInsensitiveContains(inName) }) {
        model.selectedInputDeviceID = inDev.uniqueID
    } else {
        print("Error: Input device '\(inName)' not found.")
        print("Available inputs: \(model.inputDevices.map { $0.localizedName })")
        exit(1)
    }
} else {
    print("\n🎤 Select Input Microphone:")
    var inList = model.inputDevices
    guard !inList.isEmpty else {
        print("Error: No audio input devices found.")
        exit(1)
    }
    
    // Sort default microphone to [1], and physical mics above loopbacks
    let defaultUID = AVCaptureDevice.default(for: .audio)?.uniqueID
    inList.sort { (d1, d2) -> Bool in
        if d1.uniqueID == defaultUID { return true }
        if d2.uniqueID == defaultUID { return false }
        let isVirt1 = d1.localizedName.contains("BlackHole") || d1.localizedName.contains("Boom") || d1.localizedName.contains("Steam") || d1.localizedName.contains("Teams")
        let isVirt2 = d2.localizedName.contains("BlackHole") || d2.localizedName.contains("Boom") || d2.localizedName.contains("Steam") || d2.localizedName.contains("Teams")
        if isVirt1 != isVirt2 { return !isVirt1 }
        return d1.localizedName < d2.localizedName
    }
    
    for (idx, dev) in inList.enumerated() {
        let isDefault = (dev.uniqueID == defaultUID)
        print("  [\(idx + 1)] \(dev.localizedName)\(isDefault ? " (Default Microphone)" : "")")
    }
    print("Enter choice [1-\(inList.count)] (default: 1): ", terminator: "")
    fflush(stdout)
    
    let choiceStr = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let choiceIdx = (Int(choiceStr) ?? 1) - 1
    let selectedDev = (choiceIdx >= 0 && choiceIdx < inList.count) ? inList[choiceIdx] : inList[0]
    model.selectedInputDeviceID = selectedDev.uniqueID
}

// 2. Output Device Selection
if let outName = outputName {
    if let outDev = model.outputDevices.first(where: { $0.name.localizedCaseInsensitiveContains(outName) }) {
        model.selectedOutputDeviceID = outDev.id
    } else {
        print("Error: Output device '\(outName)' not found.")
        print("Available outputs: \(model.outputDevices.map { $0.name })")
        exit(1)
    }
} else {
    print("\n🔊 Select Output Device:")
    var outList = model.outputDevices
    guard !outList.isEmpty else {
        print("Error: No audio output devices found.")
        exit(1)
    }
    
    // Sort virtual devices (BlackHole, LitLink) to [1]
    outList.sort { (d1, d2) -> Bool in
        let isVirt1 = d1.name.contains("BlackHole") || d1.name.contains("LitLink")
        let isVirt2 = d2.name.contains("BlackHole") || d2.name.contains("LitLink")
        if isVirt1 != isVirt2 { return isVirt1 }
        return d1.name < d2.name
    }
    
    for (idx, dev) in outList.enumerated() {
        let isVirtual = dev.name.contains("BlackHole") || dev.name.contains("LitLink")
        print("  [\(idx + 1)] \(dev.name)\(isVirtual ? " (Virtual Cable - Recommended)" : "")")
    }
    print("Enter choice [1-\(outList.count)] (default: 1): ", terminator: "")
    fflush(stdout)
    
    let choiceStr = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let choiceIdx = (Int(choiceStr) ?? 1) - 1
    let selectedOut = (choiceIdx >= 0 && choiceIdx < outList.count) ? outList[choiceIdx] : outList[0]
    model.selectedOutputDeviceID = selectedOut.id
}

model.outputGainValue = gain
model.isAIEnabled = aiEnabled
model.isPlayingTestTone = testTone

// --- Modern Apple-Grade Full-Width TUI Dashboard ---

func makeColorBar(rms: Float, width: Int) -> String {
    let clamped = min(max(rms * 3.5, 0.0), 1.0)
    let filled = Int(clamped * Float(width))
    let empty = max(0, width - filled)
    
    var bar = ""
    for idx in 0..<filled {
        let ratio = Float(idx) / Float(max(1, width))
        if ratio < 0.6 {
            bar += "\u{001B}[32m■" // Green
        } else if ratio < 0.85 {
            bar += "\u{001B}[33m■" // Yellow
        } else {
            bar += "\u{001B}[31m■" // Red
        }
    }
    bar += "\u{001B}[90m" + String(repeating: "·", count: empty) + "\u{001B}[0m"
    return bar
}

var showLogHistory = scrollingLogMode

if TerminalController.shared.isTTY && !showLogHistory {
    TerminalController.shared.enableRawMode()
    print("\u{001B}[2J\u{001B}[H", terminator: "") // Clear screen and home cursor
    fflush(stdout)
}

// 60ms fast smooth refresh loop (16 FPS)
let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
timer.schedule(deadline: .now() + 0.06, repeating: 0.06)
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "HH:mm:ss"

var frameCount = 0

timer.setEventHandler {
    frameCount += 1
    
    // Check non-blocking keyboard input on every frame
    if TerminalController.shared.isRaw {
        var fds = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        if poll(&fds, 1, 0) > 0 {
            var c: UInt8 = 0
            if read(STDIN_FILENO, &c, 1) > 0 {
                switch c {
                case UInt8(ascii: "q"), UInt8(ascii: "Q"), 3: // 'q' or Ctrl+C
                    TerminalController.shared.restore()
                    print("\nExiting MetalVoice CLI. Goodbye! 👋\n")
                    exit(0)
                case UInt8(ascii: "a"), UInt8(ascii: "A"):
                    model.isAIEnabled.toggle()
                case UInt8(ascii: "t"), UInt8(ascii: "T"):
                    model.isPlayingTestTone.toggle()
                case UInt8(ascii: "+"), UInt8(ascii: "="):
                    model.outputGainValue = min(model.outputGainValue + 0.1, 4.0)
                case UInt8(ascii: "-"), UInt8(ascii: "_"):
                    model.outputGainValue = max(model.outputGainValue - 0.1, 0.5)
                case UInt8(ascii: "h"), UInt8(ascii: "H"):
                    showLogHistory.toggle()
                    if !showLogHistory {
                        print("\u{001B}[2J\u{001B}[H", terminator: "") // Clear screen and home
                        fflush(stdout)
                    } else {
                        print("\n\u{001B}[90m─── Switched to Scrolling Log History (Press 'H' to return to dashboard, 'Q' to quit) ───\u{001B}[0m\n")
                        fflush(stdout)
                    }
                case UInt8(ascii: "u"), UInt8(ascii: "U"):
                    if let release = updateReleaseInfo, let downloadURL = release.downloadURL {
                        TerminalController.shared.restore()
                        print("\n\u{001B}[1;36m⬇️ Downloading and installing \(release.tagName)...\u{001B}[0m")
                        let execPath = CommandLine.arguments[0]
                        let resolvedExecPath = URL(fileURLWithPath: execPath).resolvingSymlinksInPath().path
                        
                        UpdateChecker.updateCLIBinary(downloadURL: downloadURL, currentExecutablePath: resolvedExecPath) { updateResult in
                            switch updateResult {
                            case .success(let msg):
                                print("\u{001B}[1;32m✅ \(msg)\u{001B}[0m")
                                print("Please restart MetalVoiceCLI to use the new version.")
                                exit(0)
                            case .failure(let err):
                                print("\u{001B}[1;31m❌ Update failed: \(err.localizedDescription)\u{001B}[0m")
                            }
                        }
                    }
                default:
                    break
                }
            }
        }
    }
    
    let snap = model.getDiagnosticsSnapshot()
    let timeStr = dateFormatter.string(from: snap.timestamp)
    
    if !showLogHistory && TerminalController.shared.isTTY {
        let width = TerminalController.shared.getWidth()
        let separator = String(repeating: "─", count: max(10, width - 4))
        let barWidth = max(16, min(width - 48, 38))
        
        let inBar = makeColorBar(rms: snap.inputRMS, width: barWidth)
        let outBar = makeColorBar(rms: snap.renderOutputRMS, width: barWidth)
        let gainPercent = Int(model.outputGainValue * 100)
        
        let aiBadge = model.isAIEnabled ? "\u{001B}[1;32m● ACTIVE\u{001B}[0m \u{001B}[90m(DeepFilterNet)\u{001B}[0m" : "\u{001B}[1;31m○ BYPASSED\u{001B}[0m"
        let outStatusBadge = snap.isEngineRunning ? "\u{001B}[1;32m● STREAMING\u{001B}[0m" : "\u{001B}[1;31m○ STOPPED\u{001B}[0m"
        let toneBadge = model.isPlayingTestTone ? " \u{001B}[1;33m(TEST TONE ACTIVE)\u{001B}[0m" : ""
        
        let updateBanner = updateReleaseInfo != nil ? "\n  \u{001B}[1;33m✨ New Version Available: \(updateReleaseInfo!.tagName)\u{001B}[0m \u{001B}[90m• Press [U] to update in-place\u{001B}[0m" : ""
        let updateHotKey = updateReleaseInfo != nil ? "   \u{001B}[7;1;33m U \u{001B}[0m Upgrade (\(updateReleaseInfo!.tagName))" : ""
        
        let dashboard = """
        \u{001B}[H
        \u{001B}[1;36m  MetalVoice\u{001B}[0m \u{001B}[90mv\(version) • Live Audio Pipeline\u{001B}[0m\(updateBanner)
        \u{001B}[90m  \(separator)\u{001B}[0m
        
          \u{001B}[1m🎙️  INPUT\u{001B}[0m       \u{001B}[1;37m\(snap.inputDeviceName)\u{001B}[0m \u{001B}[90m[\(snap.inputFormat)]\u{001B}[0m
             Level       [\(inBar)] \u{001B}[37m\(String(format: "%.4f", snap.inputRMS)) RMS\u{001B}[0m \u{001B}[90m(\(snap.capturePacketsPerSec) pkts/s)\u{001B}[0m
        
          \u{001B}[1m⚡  AI DSP\u{001B}[0m      \(aiBadge)     \u{001B}[1mGain:\u{001B}[0m \u{001B}[1;33m\(gainPercent)%\u{001B}[0m
             Output      [\(outBar)] \u{001B}[37m\(String(format: "%.4f", snap.renderOutputRMS)) RMS\u{001B}[0m \u{001B}[90m(\(snap.renderCallbacksPerSec) renders/s)\u{001B}[0m
        
          \u{001B}[1m📦  BUFFER\u{001B}[0m      \u{001B}[37m\(snap.ringBufferAvailable) frames\u{001B}[0m \u{001B}[90m(\(snap.ringBufferDrops) drops, \(snap.ringBufferUnderflows) underruns)\u{001B}[0m
        
          \u{001B}[1m🔊  OUTPUT\u{001B}[0m      \u{001B}[1;37m\(snap.outputDeviceName)\u{001B}[0m \u{001B}[90m[\(snap.outputFormat)]\u{001B}[0m
             Status      \(outStatusBadge)\(toneBadge)
        
        \u{001B}[90m  \(separator)\u{001B}[0m
          \u{001B}[7;1m Q \u{001B}[0m Quit   \u{001B}[7;1m A \u{001B}[0m AI (\(model.isAIEnabled ? "ON" : "OFF"))   \u{001B}[7;1m T \u{001B}[0m Tone (\(model.isPlayingTestTone ? "ON" : "OFF"))   \u{001B}[7;1m + \u{001B}[0m/\u{001B}[7;1m - \u{001B}[0m Gain (\(gainPercent)%)   \u{001B}[7;1m H \u{001B}[0m History\(updateHotKey)
        \u{001B}[90m  \(separator)\u{001B}[0m
        """
        let lines = dashboard.components(separatedBy: "\n")
        let cleanOutput = lines.map { $0 + "\u{001B}[K" }.joined(separator: "\n") + "\u{001B}[J"
        print(cleanOutput, terminator: "")
        fflush(stdout)
    } else if frameCount % 16 == 0 { // In log history mode, print 1 line per second
        print("[\(timeStr)] In: \"\(snap.inputDeviceName)\" (\(snap.inputFormat) | RMS: \(String(format: "%.4f", snap.inputRMS)) | \(snap.capturePacketsPerSec) pkts/s)")
        print("           Buf: \(snap.ringBufferAvailable) frames (drops: \(snap.ringBufferDrops), underruns: \(snap.ringBufferUnderflows))")
        print("           DSP: AI=\(model.isAIEnabled ? "ON" : "OFF") | RMS: \(String(format: "%.4f", snap.renderOutputRMS)) | \(snap.renderCallbacksPerSec) renders/s")
        print("           Out: \"\(snap.outputDeviceName)\" (\(snap.outputFormat) | Gain: \(String(format: "%.1f", model.outputGainValue))x | Engine: \(snap.isEngineRunning ? "RUNNING" : "STOPPED"))\n")
        fflush(stdout)
    }
}
timer.resume()

// Keep alive
RunLoop.main.run()
