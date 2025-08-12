import Foundation
import Core

// Quick-Start example: Capture audio from Safari for 5 seconds
func main() async throws {
    print("🎙️ AudioCap Recorder Quick-Start Example")
    print("This example captures audio from Safari browser for 5 seconds")
    print("Make sure Safari is running and playing audio...")
    
    // Check permissions
    let permissionManager = PermissionManager()
    guard permissionManager.checkScreenRecordingPermission() else {
        print("❌ Screen recording permission required")
        print("Please go to System Preferences > Privacy & Security > Screen Recording")
        print("and enable permission for this app")
        exit(1)
    }
    
    // Create output directory
    let outputDir = "output"
    try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true, attributes: nil)
    
    // Set up logger
    let logger = Logger(verbose: true)
    
    // Initialize components
    let processManager = ProcessManager()
    let fileController = FileController()
    let audioProcessor = AudioProcessor()
    
    // Discover Safari processes
    let processes: [RecorderProcessInfo]
    do {
        processes = try processManager.discoverProcesses(matching: "Safari")
        if processes.isEmpty {
            print("❌ No Safari processes found. Please start Safari and play some audio.")
            exit(1)
        }
    } catch {
        print("❌ Error discovering processes: \(error)")
        exit(1)
    }
    
    print("🔍 Found \(processes.count) Safari process(es):")
    for process in processes {
        print("   - \(process.executableName) (PID: \(process.pid))")
    }
    
    // Initialize audio capturer
    let capturer = AudioCapturer(
        permissionManager: permissionManager,
        fileController: fileController,
        audioProcessor: audioProcessor,
        outputDirectoryPath: outputDir,
        captureInputsEnabled: false,
        alacEnabled: false,
        logger: logger
    )
    
    print("⏺️ Starting capture for 5 seconds...")
    
    // Start recording Safari audio
    Task {
        do {
            try await capturer.startCapture(for: processes)
        } catch {
            print("❌ Capture error: \(error)")
        }
    }
    
    // Wait 5 seconds
    try await Task.sleep(nanoseconds: 5_000_000_000)
    
    // Stop recording
    capturer.stopCapture()
    
    print("✅ Recording complete!")
    print("📁 Check the output directory for recorded files:")
    
    // List output files
    let outputURL = URL(fileURLWithPath: outputDir)
    if let files = try? FileManager.default.contentsOfDirectory(at: outputURL, includingPropertiesForKeys: [.fileSizeKey]) {
        for file in files {
            if let attributes = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = attributes.fileSize {
                print("   📄 \(file.lastPathComponent) (\(fileSize) bytes)")
            }
        }
    }
}

// Run the example
do {
    try await main()
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
