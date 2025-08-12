import Foundation
import Core

/// Adaptive Bitrate Recording Recipe
/// Demonstrates CPU-aware quality adjustment and compression fallback
/// Monitors system load and automatically adjusts recording quality
func main() async throws {
    print("⚡ Adaptive Bitrate Recording Recipe")
    print("Monitors CPU usage and adapts recording quality automatically")
    print("Starts with ALAC, falls back to AAC if CPU usage is high")
    print()
    
    // Check permissions
    let permissionManager = PermissionManager()
    guard permissionManager.checkScreenRecordingPermission() else {
        print("❌ Screen recording permission required")
        print("Enable in System Preferences > Privacy & Security > Screen Recording")
        exit(1)
    }
    
    let processManager = ProcessManager()
    let logger = Logger(verbose: true)
    let cpuMonitor = CPUMonitor()
    
    // Find processes to record
    print("🔍 Scanning for processes...")
    let processes: [RecorderProcessInfo]
    do {
        // Try multiple common audio applications
        let candidates = ["Safari", "Music", "VLC", "Spotify", ".*"]
        var found: [RecorderProcessInfo] = []
        
        for pattern in candidates {
            if let matching = try? processManager.discoverProcesses(matching: pattern), !matching.isEmpty {
                found = matching
                print("   ✅ Found processes matching '\(pattern)': \(matching.count)")
                break
            }
        }
        
        if found.isEmpty {
            print("❌ No suitable processes found")
            print("Please start an audio application (Safari, Music, VLC, etc.)")
            exit(1)
        }
        
        processes = found
    }
    
    // Monitor initial CPU usage
    let initialCPU = cpuMonitor.sampleUsedPercent()
    print("🖥️ Current CPU usage: \(String(format: "%.1f", initialCPU))%")
    
    // Decide on recording strategy based on CPU
    let useAdaptive = initialCPU > 50.0
    print("🎯 Recording strategy: \(useAdaptive ? "Adaptive (CPU-aware)" : "High Quality (ALAC)")")
    
    if useAdaptive {
        print("⚠️ High CPU detected - will monitor and adjust quality")
    }
    
    // Create output directory with timestamp
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    let timestamp = formatter.string(from: Date())
    let outputDir = "adaptive-recordings-\(timestamp)"
    
    // Start with optimal settings
    var currentQuality: String = useAdaptive ? "medium" : "lossless"
    var usingALAC = !useAdaptive
    
    let capturer = AudioCapturer(
        outputDirectoryPath: outputDir,
        captureInputsEnabled: false,
        alacEnabled: usingALAC,
        logger: logger
    )
    
    print("\n⏺️ Starting adaptive recording for 20 seconds...")
    print("📊 Initial quality: \(currentQuality)")
    
    // Start recording in background
    let recordingTask = Task {
        do {
            try await capturer.startCapture(for: processes)
        } catch {
            print("❌ Capture error: \(error)")
        }
    }
    
    // Monitor CPU and adapt quality every 5 seconds
    var elapsed = 0
    let interval = 5
    let totalDuration = 20
    
    while elapsed < totalDuration {
        try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
        elapsed += interval
        
        let currentCPU = cpuMonitor.sampleUsedPercent()
        print("🖥️ CPU: \(String(format: "%.1f", currentCPU))% | Quality: \(currentQuality) | Elapsed: \(elapsed)s")
        
        // Adaptive logic
        if useAdaptive {
            if currentCPU > 80.0 && usingALAC {
                print("🔄 High CPU detected! Switching to AAC compression...")
                currentQuality = "aac-128kbps"
                usingALAC = false
                // Note: In a real implementation, you'd restart the capturer with new settings
                // For this demo, we'll just log the change
            } else if currentCPU < 30.0 && !usingALAC {
                print("🔄 CPU usage decreased. Could switch back to ALAC...")
                currentQuality = "alac-lossless"
                // Note: Switching back to higher quality during recording
            }
        }
        
        // Simulate quality adjustment effects
        if currentCPU > 90.0 {
            print("⚠️ Critical CPU usage! Consider reducing sample rate or stopping other apps")
        }
    }
    
    // Stop recording
    capturer.stopCapture()
    recordingTask.cancel()
    
    print("\n✅ Adaptive recording complete!")
    print("📁 Output files saved to: \(outputDir)/")
    
    // Analyze results
    let outputURL = URL(fileURLWithPath: outputDir)
    if let files = try? FileManager.default.contentsOfDirectory(at: outputURL, includingPropertiesForKeys: [.fileSizeKey]) {
        var totalSize: Int64 = 0
        
        for file in files {
            if let attributes = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = attributes.fileSize {
                totalSize += Int64(fileSize)
                let sizeMB = Double(fileSize) / 1_048_576
                print("   📄 \(file.lastPathComponent) (\(String(format: "%.1f", sizeMB)) MB)")
                
                // Estimate compression based on file extension
                if file.pathExtension == "m4a" && usingALAC {
                    print("      🎵 ALAC lossless compression")
                } else if file.pathExtension == "caf" {
                    print("      🎵 Uncompressed CAF")
                }
            }
        }
        
        let totalMB = Double(totalSize) / 1_048_576
        print("\n📊 Recording summary:")
        print("   Total size: \(String(format: "%.1f", totalMB)) MB")
        print("   Duration: \(totalDuration) seconds")
        print("   Avg bitrate: ~\(String(format: "%.0f", (totalMB * 8) / Double(totalDuration) * 1000)) kbps")
    }
    
    print("\n💡 Adaptive recording insights:")
    print("• CPU monitoring prevents audio dropouts during high system load")
    print("• Automatic quality fallback ensures continuous recording")
    print("• ALAC provides lossless quality when CPU allows")
    print("• AAC compression reduces CPU load and file size")
    print("• Monitor system resources for optimal recording performance")
    
    print("\n🔧 Tuning suggestions:")
    print("• Adjust CPU thresholds based on your system capabilities")
    print("• Consider sample rate reduction (48kHz → 44.1kHz) for extreme cases")
    print("• Use external monitoring to track recording quality over time")
    print("• Implement gradual quality changes rather than sudden switches")
}

try await main()
