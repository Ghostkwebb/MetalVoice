import SwiftUI
import CoreAudio

struct ContentView: View {
    @ObservedObject var audioModel: AudioModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                if let path = Bundle.main.path(forResource: "MetalVoiceLogo", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .cornerRadius(8)
                } else {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading) {
                    Text("MetalVoice")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("AI Audio Enhancer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Settings Button
                Button(action: {
                    WindowManager.openSettings(model: audioModel)
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
            
            Divider()
            
            // Status
            HStack {
                Circle()
                    .fill(audioModel.isAIEnabled ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(audioModel.isAIEnabled ? "AI Active" : "Passthrough")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                // Meter
                MeterView(level: audioModel.inputLevel)
                    .frame(width: 100, height: 6)
            }
            
            // Devices
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Input Device", systemImage: "mic.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $audioModel.selectedInputDeviceID) {
                        ForEach(audioModel.inputDevices, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(device.uniqueID)
                        }
                    }
                    .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("Output Device", systemImage: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $audioModel.selectedOutputDeviceID) {
                        ForEach(audioModel.outputDevices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .labelsHidden()
                }
            }
            
            Divider()
            
            // Controls
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $audioModel.isAIEnabled) {
                    Text("DeepFilterNet AI")
                        .fontWeight(.medium)
                }
                .toggleStyle(.switch)
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
                
                Spacer()
                
                if let error = audioModel.errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .help(error)
                }
            }
        }
        .padding()
        .frame(width: 280)
    }
}

struct MeterView: View {
    var level: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .opacity(0.2)
                    .foregroundColor(.gray)
                
                Capsule()
                    .frame(width: min(CGFloat(level) * 5 * geometry.size.width, geometry.size.width))
                    .foregroundColor(level > 0.01 ? .green : .gray)
                    .animation(.linear(duration: 0.1), value: level)
            }
        }
    }
}

class WindowManager {
    static var settingsWindow: NSWindow?
    
    static func openSettings(model: AudioModel) {
        if settingsWindow == nil {
            let view = SettingsView(audioModel: model)
            // Standard Window (Larger Buttons + Resizable)
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                backing: .buffered, defer: false)
            panel.center()
            panel.title = "MetalVoice Settings"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.contentView = NSHostingView(rootView: view)
            panel.isFloatingPanel = false
            panel.isReleasedWhenClosed = false 
            panel.minSize = NSSize(width: 450, height: 350) 
            
            settingsWindow = panel
            
            // Cleanup on close
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: nil) { _ in
                settingsWindow = nil
            }
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
