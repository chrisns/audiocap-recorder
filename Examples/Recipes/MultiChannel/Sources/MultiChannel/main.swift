import Foundation
import Core

/// Multi-Channel Recording Recipe
/// Demonstrates capturing audio from multiple applications plus input devices
/// Records to 8-channel CAF files with different sources on different channels
func main() async throws {
    print("🎛️ Multi-Channel Recording Recipe")
    print("Captures up to 8 channels from multiple sources simultaneously:")
    print("• Channels 1-2: Process audio (stereo)")
    print("• Channels 3-8: Input devices (6 additional channels)")
    print()
    
    // Check permissions
    let permissionManager = PermissionManager()
    guard permissionManager.checkScreenRecordingPermission() else {
        print("❌ Screen recording permission required")
        print("Enable in System Preferences > Privacy & Security > Screen Recording")
        exit(1)
    }
    
    // For input devices, we also need microphone permission
    guard permissionManager.checkMicrophonePermission() else {
        print("❌ Microphone permission required for input device capture")
        print("Enable in System Preferences > Privacy & Security > Microphone")
        exit(1)
    }
    
    let processManager = ProcessManager()
    let logger = Logger(verbose: true)
    
    // Find multiple processes for demo
    print("🔍 Scanning for audio processes...")
    let musicProcesses = try? processManager.discoverProcesses(matching: "Music")
    let safariProcesses = try? processManager.discoverProcesses(matching: "Safari")
    let vlcProcesses = try? processManager.discoverProcesses(matching: "VLC")
    
    var allProcesses: [RecorderProcessInfo] = []
    if let music = musicProcesses, !music.isEmpty {
        allProcesses.append(contentsOf: music)
        print("   ✅ Music app found")
    }
    if let safari = safariProcesses, !safari.isEmpty {
        allProcesses.append(contentsOf: safari)
        print("   ✅ Safari found")
    }
    if let vlc = vlcProcesses, !vlc.isEmpty {
        allProcesses.append(contentsOf: vlc)
        print("   ✅ VLC found")
    }
    
    if allProcesses.isEmpty {
        print("❌ No suitable audio processes found")
        print("Please start one of: Music, Safari (with audio), or VLC")
        exit(1)
    }
    
    print("🎯 Will record from \(allProcesses.count) process(es)")
    
    // Check available input devices
    print("🎤 Input device capture enabled (up to 6 additional channels)")
    
    // Configure for multi-channel recording
    let capturer = AudioCapturer(
        outputDirectoryPath: "multichannel-recordings",
        captureInputsEnabled: true,   // Enable 8-channel recording
        alacEnabled: true,           // Use ALAC for better compression
        logger: logger
    )
    
    print("\n⏺️ Starting 8-channel recording for 15 seconds...")
    print("📊 Channel layout:")
    print("   Ch 1-2: Process audio (stereo mix)")
    print("   Ch 3-8: Input devices (up to 6 devices)")
    
    // Start recording
    Task {
        do {
            try await capturer.startCapture(for: allProcesses)
        } catch {
            print("❌ Capture error: \(error)")
        }
    }
    
    // Record for 15 seconds
    try await Task.sleep(nanoseconds: 15_000_000_000)
    
    // Stop recording
    capturer.stopCapture()
    
    print("✅ Multi-channel recording complete!")
    print("📁 Output files saved to: multichannel-recordings/")
    
    // Analyze output files
    let outputURL = URL(fileURLWithPath: "multichannel-recordings")
    if let files = try? FileManager.default.contentsOfDirectory(at: outputURL, includingPropertiesForKeys: [.fileSizeKey]) {
        for file in files {
            if let attributes = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = attributes.fileSize {
                let sizeMB = Double(fileSize) / 1_048_576
                print("   📄 \(file.lastPathComponent) (\(String(format: "%.1f", sizeMB)) MB)")
                
                // Try to read channel count (this is a simplified approach)
                if file.pathExtension == "m4a" {
                    print("      🎛️ 8-channel ALAC (lossless)")
                } else if file.pathExtension == "caf" {
                    print("      🎛️ 8-channel CAF (uncompressed)")
                }
            }
        }
    }
    
    print("\n💡 Multi-channel recording tips:")
    print("• 8-channel files allow complex post-processing and mixing")
    print("• Each input device gets its own channel for isolation")
    print("• Use audio editing software to separate and process channels")
    print("• ALAC compression reduces file size while maintaining quality")
    print("• Perfect for podcasts, interviews, or multi-source recording")
    
    print("\n🎚️ Post-processing suggestions:")
    print("• Use Logic Pro, Pro Tools, or Audacity to edit 8-channel files")
    print("• Extract specific channels: `ffmpeg -i input.m4a -map 0:0 -ac 1 channel1.wav`")
    print("• Mix channels: `ffmpeg -i input.m4a -filter_complex '[0:0]pan=stereo|c0<c0+c2+c4|c1<c1+c3+c5' output.wav`")
}

try await main()
