# Implementation Plan

- [x] 1. Set up project structure and core interfaces

  - Create Swift Package Manager project with proper directory structure
  - Define protocol interfaces for all major components (ProcessManager, AudioCapturer, AudioProcessor, FileController)
  - Set up Package.swift with dependencies (Swift ArgumentParser, XCTest)
  - Create basic error types and data models
  - _Requirements: 1.1, 5.1, 7.1_

- [x] 2. Implement CLI interface with ArgumentParser

  - Create main CLI struct conforming to ParsableCommand
  - Define command-line arguments (@Argument for regex, @Option for output directory, @Flag for verbose)
  - Implement argument validation and help text
  - Add permission checking and user guidance for ScreenCaptureKit permissions
  - Write unit tests for CLI argument parsing and validation
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 10.1, 10.2, 10.3_

- [x] 3. Create process discovery and monitoring system

  - Implement ProcessManager class with NSRunningApplication integration
  - Add regex matching functionality using NSRegularExpression
  - Create process filtering logic for executable names and paths
  - Implement process lifecycle monitoring with NSWorkspace notifications
  - Write unit tests for process discovery and regex matching
  - _Requirements: 1.1, 1.3, 4.1, 4.2_

- [x] 4. Build ScreenCaptureKit audio capture foundation

  - Create AudioCapturer class conforming to SCStreamDelegate
  - Implement ScreenCaptureKit configuration with proper audio settings
  - Set up SCStream initialization with system audio capture
  - Handle SCStreamOutputType.audio sample buffers in delegate method
  - Add error handling for ScreenCaptureKit failures and permission issues
  - Write integration tests for audio capture setup
  - _Requirements: 4.1, 4.3, 4.4, 10.1, 10.2, 10.3, 10.4_

- [x] 5. Implement audio processing and correlation system

  - Create AudioProcessor class for handling CMSampleBuffer conversion to AVAudioPCMBuffer
  - Implement process-audio correlation logic using activity monitoring
  - Add audio stream mixing functionality for multiple target processes
  - Create WAV format conversion using Core Audio services
  - Write unit tests for audio buffer processing and mixing
  - _Requirements: 1.2, 1.4, 11.1, 11.2, 11.3, 11.4_

- [x] 6. Build file management and output system

  - Implement FileController class for directory creation and file operations
  - Create timestamped filename generation (yyyy-MM-dd-HH-mm-ss.wav format)
  - Add WAV file writing with proper audio format headers
  - Implement default and custom output directory handling
  - Write unit tests for file operations and directory management
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4_

- [x] 7. Add real-time recording feedback and duration limits

  - Implement recording duration tracking and display updates
  - Add 12-hour maximum recording limit with automatic stop
  - Create real-time duration display that updates every second
  - Implement graceful recording termination and file saving
  - Write unit tests for duration tracking and limits
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [x] 8. Implement graceful shutdown and signal handling

  - Add SIGINT (Ctrl+C) signal handling for clean shutdown
  - Implement proper cleanup of ScreenCaptureKit resources
  - Ensure audio data is saved when recording is interrupted
  - Add final recording summary with file location and duration
  - Write integration tests for shutdown scenarios
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 9. Create comprehensive error handling and user guidance

  - Implement detailed error messages for all failure scenarios
  - Add step-by-step permission setup instructions
  - Create fallback behaviors for partial failures
  - Implement logging system with verbose mode support
  - Write unit tests for error handling and recovery
  - _Requirements: 1.3, 4.3, 5.2, 10.1, 10.2, 10.3, 10.4_

- [x] 10. Build testing infrastructure and test coverage

  - Create mock implementations for all protocol interfaces
  - Write comprehensive unit tests for each component
  - Implement integration tests for audio capture workflows
  - Add performance tests for memory usage and CPU impact
  - Ensure 80% code coverage across all modules
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 11. Set up GitHub Actions CI/CD pipeline

  - Create GitHub Actions workflow for automated testing
  - Configure macOS runners for ScreenCaptureKit compatibility
  - Add build validation for Swift Package Manager
  - Implement automated binary creation for releases
  - Set up test failure notifications and merge protection
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 12. Integrate all components and implement main application flow

  - Wire together CLI, ProcessManager, AudioCapturer, AudioProcessor, and FileController
  - Implement complete recording session lifecycle
  - Add proper resource cleanup and memory management
  - Create end-to-end integration tests
  - Verify all requirements are met through comprehensive testing
  - _Requirements: All requirements integration and validation_

- [x] 13. Fix system audio capture and WAV writing, and verify waveform contains audio

  - Correct CMSampleBuffer → AVAudioPCMBuffer conversion using CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer and proper format handling
  - Ensure SCStream/SCContentFilter configuration includes system audio
  - Create and write WAV files continuously with a reasonable file size
  - Verify end-to-end by recording Chrome for ~10–15s, confirm file exists in `~/Documents/audiocap/`, size is reasonable, and RMS amplitude > 0
  - Run all tests and ensure they pass

- [x] 14. Automated test: spawn sinewave process, capture, and verify size and frequency

  - Create a lightweight helper executable target `SineWavePlayer` that plays a pure sine tone (default 1 kHz) to the system output using `AVAudioEngine`
  - Add an integration test `SineCaptureTests` that:
    - Builds and launches `SineWavePlayer` as a separate process
    - Runs `audiocap-recorder` targeting the helper process via regex (e.g., `(?i)SineWavePlayer`), outputting to a temporary directory
    - Records for a fixed duration (e.g., 5 seconds), then sends SIGINT to stop
    - Locates the produced WAV file and asserts size is within ±20% of expected bytes (48 kHz × 2ch × 4 bytes × duration)
    - Loads the WAV via `AVAudioFile` and performs frequency analysis (FFT or autocorrelation) to detect a dominant tone near 1 kHz (±50 Hz)
  - Ensure the test is marked as integration-only and can be skipped on CI if permissions are unavailable (but runnable locally)
  - Update `Package.swift` to include the new helper target and the integration test
  - All existing tests must continue to pass

- [x] 15. Add --capture-inputs CLI option and update argument parsing

  - Add `@Flag(name: .shortAndLong, help: "Capture all audio input devices in addition to process audio") var captureInputs: Bool = false` to AudioRecorderCLI
  - Update help text and usage examples to include the new flag
  - Modify main application flow to conditionally enable input device capture based on flag
  - Add validation to ensure microphone permissions are checked when --capture-inputs is used
  - Write unit tests for CLI argument parsing with the new flag
  - _Requirements: 12.1, 14.1_

- [ ] 16. Implement InputDeviceManager for audio input device enumeration and monitoring

  - Create InputDeviceManager class with AVFoundation integration for device discovery
  - Implement device enumeration using AVAudioSession and AVCaptureDevice APIs
  - Add device metadata collection (name, UID, channel count, sample rate)
  - Create device connection/disconnection monitoring using AVAudioSession.routeChangeNotification
  - Implement channel assignment logic for up to 6 input devices (channels 3-8)
  - Write unit tests for device enumeration and channel assignment
  - _Requirements: 12.1, 12.2, 13.1, 13.2_

- [ ] 17. Build audio input device capture system with AVAudioEngine

  - Create audio capture setup for each discovered input device using AVAudioEngine
  - Implement per-device audio buffer capture with proper format conversion to 48kHz
  - Add device-specific audio processing and sample rate conversion
  - Create audio buffer routing to assigned channels (3-8)
  - Handle device-specific audio format differences and channel mapping
  - Write integration tests for multi-device audio capture
  - _Requirements: 12.1, 12.2, 12.3_

- [ ] 18. Implement device hot-swapping and reconnection handling

  - Add real-time device connection/disconnection detection using AVAudioSession notifications
  - Implement automatic channel reassignment when devices connect/disconnect
  - Create device reconnection logic that restores previous channel assignments when possible
  - Add graceful handling of device disconnection during active recording
  - Log device events with timestamps for channel mapping reference
  - Write unit tests for hot-swapping scenarios and edge cases
  - _Requirements: 13.1, 13.2, 13.3, 13.4_

- [ ] 19. Enhance AudioProcessor for 8-channel audio processing

  - Modify AudioProcessor to handle 8-channel audio buffer creation and management
  - Implement audio buffer combination logic (process audio on channels 1-2, input devices on 3-8)
  - Add sample rate synchronization between process audio and input device audio
  - Create buffer alignment and timestamp correlation for multi-source audio
  - Implement silent channel handling for unused input device channels
  - Write unit tests for 8-channel audio processing and buffer management
  - _Requirements: 12.2, 12.3, 12.4_

- [ ] 20. Update FileController for 8-channel WAV output and channel mapping logs

  - Modify WAV file writing to support 8-channel audio format using AudioToolbox
  - Create channel mapping log file generation in JSON format alongside WAV files
  - Implement real-time channel mapping updates when devices connect/disconnect
  - Add device event logging with timestamps and channel assignments
  - Update file naming convention to include channel mapping files (e.g., filename-channels.json)
  - Write unit tests for 8-channel WAV creation and channel mapping file generation
  - _Requirements: 12.2, 14.2, 14.3, 14.4_

- [ ] 21. Add microphone permission handling and user guidance

  - Implement microphone permission checking using AVAudioSession authorization
  - Add permission request flow for microphone access when --capture-inputs is used
  - Create user guidance messages for enabling microphone permissions in System Preferences
  - Update PermissionManager to handle both screen recording and microphone permissions
  - Add graceful fallback when microphone permissions are denied (process-only recording)
  - Write unit tests for permission handling and user guidance flows
  - _Requirements: 12.1, 14.4_

- [ ] 22. Integrate input device capture with main recording workflow

  - Wire InputDeviceManager into main application lifecycle alongside existing components
  - Coordinate input device capture startup/shutdown with process audio capture
  - Implement proper resource cleanup for input devices and audio engines
  - Add real-time status display showing active input devices and channel assignments
  - Create unified error handling for both process audio and input device failures
  - Write integration tests for complete 8-channel recording workflow
  - _Requirements: 12.1, 13.1, 14.1, 14.2_

- [ ] 23. Add comprehensive testing for multi-channel audio functionality

  - Create mock input devices for testing device enumeration and hot-swapping
  - Implement integration tests for 8-channel audio capture and WAV file validation
  - Add performance tests for multi-device audio processing and memory usage
  - Create end-to-end tests combining process audio and input device capture
  - Verify channel mapping logs are accurate and properly formatted
  - Ensure all existing tests continue to pass with new multi-channel functionality
  - _Requirements: 12.1, 12.2, 13.1, 13.2, 14.1, 14.2_

- [ ] 24. Update documentation and finalize multi-channel audio feature

  - Update README.md with comprehensive documentation of the new --capture-inputs feature
  - Document 8-channel WAV output format and channel mapping (channels 1-2: process audio, 3-8: input devices)
  - Add usage examples showing how to use --capture-inputs flag with process regex patterns
  - Document device hot-swapping behavior and channel mapping log files
  - Include microphone permission requirements and setup instructions
  - Add troubleshooting section for common input device issues
  - Update command-line help examples and usage scenarios
  - Verify all code documentation and comments are up to date
  - Run final integration tests to ensure all features work together
  - _Requirements: 12.1, 12.2, 13.1, 13.2, 14.1, 14.2, 14.3, 14.4_
