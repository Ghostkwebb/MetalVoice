import Foundation
import Core

print("MetalVoice CLI 🎙️")

// Basic Arg Parsing
var inputName: String?
var outputName: String?
var gain: Float = 1.0

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
    case "--help":
        print("Usage: MetalVoiceCLI [--in <input device>] [--out <output device>] [--gain <float>]")
        exit(0)
    default:
        break
    }
    i += 1
}

guard let input = inputName, let output = outputName else {
    print("Error: Missing --in or --out.")
    print("Usage: MetalVoiceCLI --in \"Built-in Microphone\" --out \"BlackHole 2ch\"")
    exit(1)
}

let model = AudioModel()

// Wait a tiny bit for fetch devices to complete (it's async in AudioModel)
RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))

// Find devices
print("Available Inputs: \(model.inputDevices.map { $0.localizedName })")
if let inDev = model.inputDevices.first(where: { $0.localizedName.localizedCaseInsensitiveContains(input) }) {
    print("Selecting Input: \(inDev.localizedName)")
    model.selectedInputDeviceID = inDev.uniqueID
} else {
    print("Error: Input device '\(input)' not found.")
    exit(1)
}

print("Available Outputs: \(model.outputDevices.map { $0.name })")
if let outDev = model.outputDevices.first(where: { $0.name.localizedCaseInsensitiveContains(output) }) {
    print("Selecting Output: \(outDev.name)")
    model.selectedOutputDeviceID = outDev.id
} else {
    print("Error: Output device '\(output)' not found.")
    exit(1)
}

model.outputGainValue = gain
model.isAIEnabled = true

print("AI Pipeline Active. Press Ctrl+C to stop.")

// Keep alive
RunLoop.main.run()
