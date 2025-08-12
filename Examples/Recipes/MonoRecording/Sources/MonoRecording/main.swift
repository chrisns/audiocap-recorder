import Foundation
import Core

/// Mono Recording Recipe
/// Demonstrates capturing audio from Music app and downmixing to mono
func main() async throws {
    print("🎵 Mono Recording Recipe")
    print("Captures audio from Music app and outputs mono CAF files")
    print("Make sure Music app is running and playing audio...")
    
    // Check permissions
    let permissionManager = PermissionManager()
    guard permissionManager.checkScreenRecordingPermission() else {
        print("❌ Screen recording permission required")
        print("Enable in System Preferences > Privacy & Security > Screen Recording")
        exit(1)
    }
    
    let processManager = ProcessManager()
    let logger = Logger(verbose: true)
    
    // Find Music processes
    let processes = try processManager.discoverProcesses(matching: "Music")
    if processes.isEmpty {
        print("❌ No Music processes found")
        print("Please start the Music app and play some audio")
        exit(1)
    }
    
    print("🔍 Found Music process: \(processes.first!.executableName)")
    
    // Configure for mono recording
    // Note: The library captures in stereo and we'll process to mono
    let capturer = AudioCapturer(
        outputDirectoryPath: "mono-recordings",
        captureInputsEnabled: false,
        alacEnabled: false,  // Use CAF for simplicity
        logger: logger
    )
    
    print("⏺️ Recording in mono for 10 seconds...")
    print("📝 Note: Audio captured in stereo, downmixed to mono during processing")
    
    // Start recording
    Task {
        do {
            try await capturer.startCapture(for: processes)
        } catch {
            print("❌ Capture error: \(error)")
        }
    }
    
    // Record for 10 seconds
    try await Task.sleep(nanoseconds: 10_000_000_000)
    
    // Stop recording
    capturer.stopCapture()
    
    print("✅ Mono recording complete!")
    print("📁 Output files saved to: mono-recordings/")
    
    // List output files with size info
    let outputURL = URL(fileURLWithPath: "mono-recordings")
    if let files = try? FileManager.default.contentsOfDirectory(at: outputURL, includingPropertiesForKeys: [.fileSizeKey]) {
        for file in files {
            if let attributes = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = attributes.fileSize {
                let sizeMB = Double(fileSize) / 1_048_576
                print("   📄 \(file.lastPathComponent) (\(String(format: "%.1f", sizeMB)) MB)")
            }
        }
    }
    
    print("\n💡 Tips:")
    print("• Mono files are ~50% smaller than stereo")
    print("• Ideal for voice recordings or when stereo separation isn't needed")
    print("• Use ALAC compression for even smaller lossless files")
}

try await main()
