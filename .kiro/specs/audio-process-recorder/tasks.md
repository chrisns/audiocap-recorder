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

- [x] 16. Implement InputDeviceManager for audio input device enumeration and monitoring

  - Create InputDeviceManager class with AVFoundation integration for device discovery
  - Implement device enumeration using AVAudioSession and AVCaptureDevice APIs
  - Add device metadata collection (name, UID, channel count, sample rate)
  - Create device connection/disconnection monitoring using AVAudioSession.routeChangeNotification
  - Implement channel assignment logic for up to 6 input devices (channels 3-8)
  - Write unit tests for device enumeration and channel assignment
  - _Requirements: 12.1, 12.2, 13.1, 13.2_

- [x] 16.1 Add aggregate and virtual audio device filtering to InputDeviceManager

  - Implement Core Audio device type detection using AudioObjectGetPropertyData with kAudioDevicePropertyTransportType
  - Add filtering logic to exclude devices with transport type kAudioDeviceTransportTypeAggregate
  - Add filtering logic to exclude devices with transport type kAudioDeviceTransportTypeVirtual
  - Implement manufacturer string checking to exclude devices containing "Aggregate" or "Virtual" keywords
  - Create AudioDeviceType enum (physical, aggregate, virtual, unknown) and add type detection to AudioInputDevice struct
  - Add isPhysicalInputDevice() and filterAggregateAndVirtualDevices() private methods to InputDeviceManager
  - Log excluded devices with their type and exclusion reason for debugging purposes
  - Write unit tests for device filtering with mock aggregate and virtual devices
  - Write integration tests to verify only physical devices are included in enumeration
  - _Requirements: 15.1, 15.2, 15.3, 15.4_

- [x] 17. Build audio input device capture system with AVAudioEngine

  - Create audio capture setup for each discovered input device using AVAudioEngine
  - Implement per-device audio buffer capture with proper format conversion to 48kHz
  - Add device-specific audio processing and sample rate conversion
  - Create audio buffer routing to assigned channels (3-8)
  - Handle device-specific audio format differences and channel mapping
  - Write integration tests for multi-device audio capture
  - _Requirements: 12.1, 12.2, 12.3_

- [x] 18. Implement device hot-swapping and reconnection handling

  - Add real-time device connection/disconnection detection using AVAudioSession notifications
  - Implement automatic channel reassignment when devices connect/disconnect
  - Create device reconnection logic that restores previous channel assignments when possible
  - Add graceful handling of device disconnection during active recording
  - Log device events with timestamps for channel mapping reference
  - Write unit tests for hot-swapping scenarios and edge cases
  - _Requirements: 13.1, 13.2, 13.3, 13.4_

- [x] 19. Enhance AudioProcessor for 8-channel audio processing

  - Modify AudioProcessor to handle 8-channel audio buffer creation and management
  - Implement audio buffer combination logic (process audio on channels 1-2, input devices on 3-8)
  - Add sample rate synchronization between process audio and input device audio
  - Create buffer alignment and timestamp correlation for multi-source audio
  - Implement silent channel handling for unused input device channels
  - Write unit tests for 8-channel audio processing and buffer management
  - _Requirements: 12.2, 12.3, 12.4_

- [x] 20. Update FileController for 8-channel WAV output and channel mapping logs

  - Modify WAV file writing to support 8-channel audio format using AudioToolbox
  - Create channel mapping log file generation in JSON format alongside WAV files
  - Implement real-time channel mapping updates when devices connect/disconnect
  - Add device event logging with timestamps and channel assignments
  - Update file naming convention to include channel mapping files (e.g., filename-channels.json)
  - Write unit tests for 8-channel WAV creation and channel mapping file generation
  - _Requirements: 12.2, 14.2, 14.3, 14.4_

- [x] 21. Add microphone permission handling and user guidance

  - Implement microphone permission checking using AVAudioSession authorization
  - Add permission request flow for microphone access when --capture-inputs is used
  - Create user guidance messages for enabling microphone permissions in System Preferences
  - Update PermissionManager to handle both screen recording and microphone permissions
  - Add graceful fallback when microphone permissions are denied (process-only recording)
  - Write unit tests for permission handling and user guidance flows
  - _Requirements: 12.1, 14.4_

- [x] 22. Integrate input device capture with main recording workflow

  - Wire InputDeviceManager into main application lifecycle alongside existing components
  - Coordinate input device capture startup/shutdown with process audio capture
  - Implement proper resource cleanup for input devices and audio engines
  - Add real-time status display showing active input devices and channel assignments
  - Create unified error handling for both process audio and input device failures
  - Write integration tests for complete 8-channel recording workflow
  - _Requirements: 12.1, 13.1, 14.1, 14.2_

- [x] 23. Add comprehensive testing for multi-channel audio functionality

  - Create mock input devices for testing device enumeration and hot-swapping
  - Implement integration tests for 8-channel audio capture and WAV file validation
  - Add performance tests for multi-device audio processing and memory usage
  - Create end-to-end tests combining process audio and input device capture
  - Verify channel mapping logs are accurate and properly formatted
  - Ensure all existing tests continue to pass with new multi-channel functionality
  - _Requirements: 12.1, 12.2, 13.1, 13.2, 14.1, 14.2_

- [x] 24. Update documentation and finalize multi-channel audio feature

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

- [x] 25. Verify and fix 8-channel WAV output functionality

  - Create comprehensive integration test that records with --capture-inputs flag enabled
  - Use AVAudioFile to load the generated WAV file and verify it has exactly 8 channels
  - Test channel assignment by generating distinct audio signals on different input devices and verifying they appear on correct channels (3-8)
  - Verify process audio appears correctly on channels 1-2 (stereo mix)
  - Add test to ensure unused input device channels (when fewer than 6 devices) are properly silent (zero-filled)
  - Create test with multiple input devices connected to verify proper channel mapping and no audio bleeding between channels
  - If 8-channel output is not working correctly, debug and fix AudioProcessor's combineWithInputDevices() method
  - If WAV file creation is incorrect, debug and fix FileController's writeMultiChannelAudioData() method using AudioToolbox
  - Verify WAV file headers contain correct channel count, sample rate (48kHz), and bit depth (16-bit) metadata
  - Add automated test that fails if generated WAV file is not exactly 8 channels, ensuring regression prevention
  - _Requirements: 12.2, 12.3, 14.1, 14.2_

- [x] 26. Fix output file extensions to WAV and ensure multichannel recording writes WAVE

  - Update FileController to write `.wav` instead of `.caf` in `writeAudioData` and `writeMultiChannelAudioData`
  - Ensure AudioCapturer uses `.wav` filenames
  - Change ExtAudioFile creation to `kAudioFileWAVEType` and destination format to 8-ch 16-bit PCM, with non-interleaved float client format
  - Run all tests and ensure they pass

- [x] 27. Switch multichannel output to CAF and align tests with CAF

  - Update FileController to write `.caf` for generic and multichannel data
  - Update AudioCapturer to generate `.caf` filenames and use `kAudioFileCAFType`
  - Configure CAF destination as 8-ch Float32 non-interleaved; client format matches for zero-copy
  - Update tests to expect `.caf` filenames and mapping behavior
  - Run all tests and ensure they pass

- [x] 28. Eagerly create CAF file on start for -c to guarantee file presence

  - Initialize `ExtAudioFile` in `AudioCapturer.startCapture` when `captureInputsEnabled == true`
  - Use 8-ch Float32 non-interleaved destination and client formats
  - Keep lazy path as fallback if needed; ensure dispose on stop
  - Verify file is present even if no audio flows
  - Run all tests and ensure they pass

- [x] 28.1. Create CAF file before starting SC stream to guarantee immediate presence

  - Move eager ExtAudioFile initialization to occur before `stream.startCapture()`
  - Ensure directory exists and file creation succeeds irrespective of stream start
  - Run all tests and ensure they pass
 
- [ ] 31. Harden output directory creation and CAF creation with -c

  - Replace silent directory creation with strict do/catch and fallback to default directory
  - If both target and default directories fail, throw a file system error and exit
  - On -c, if `ExtAudioFileCreateWithURL` fails, throw a file system error (do not continue)
  - Log the chosen output directory and intended filename at start
  - Run all tests and ensure they pass

- [ ] 32. Write on input audio callbacks to ensure multichannel file grows even if SC audio is silent

  - In `AudioCapturer.receiveInputAudio`, when -c is enabled and ExtAudioFile is open, compose an 8ch buffer with process channels zeroed and the device's channel filled, then write it
  - Keep SC stream writes as-is for process audio
  - This guarantees file growth driven by input devices
  - Run all tests and ensure they pass

- [ ] 33. Switch multichannel CAF writing to AVAudioFile (simpler and reliable)

  - Replace ExtAudioFile-based writes with `AVAudioFile` opened on an 8-ch Float32 non-interleaved CAF
  - Write the assembled buffers via `AVAudioFile.write(from:)` in both SC and input paths
  - Remove ExtAudioFile state; keep a single `AVAudioFile` handle
  - Run all tests and ensure they pass

- [x] 34. Fix AudioBufferList allocation to prevent heap corruption

  - Allocate `AudioBufferList` using raw pointer with correct byte count for channelCount buffers
  - Initialize memory and bind to `AudioBufferList` before populating
  - Free channel buffers and raw ABL memory safely
  - Verify no crash during initial silence write and input writes
  - Run all tests and verify CLI run produces growing CAF without crashing
 
- [x] 35. Add integration test to verify CAF file grows with --capture-inputs

  - Create new test that runs recorder with -c to a temp dir for ~3–5s
  - Skip on CI or when Screen Recording or Microphone permission is not granted or no main display
  - After SIGINT, assert a .caf file exists and size > 12 KB (greater than header)
  - Use AUDIOCAP_SKIP_PROCESS_CHECK=1 to avoid dependency on running processes
  - Ensure tests pass

- [x] 36. Fix InputDeviceManagerDelegate retention issue

  - Store CombinedInputDelegate instance to prevent deallocation
  - Verify microphone audio is captured to channel 3
  - Verify process audio (Chrome) is captured to channels 1-2
  - Confirm 8-channel CAF file with proper audio levels

- [x] 37. Flatten all audio to mono for maximum device support

  - Update AudioProcessor to mix stereo process audio to mono
  - Change process audio from channels 1-2 to channel 1 only
  - Update InputDeviceManager to use channels 2-8 (7 channels for input devices)
  - Update AudioCapturer to write mono process audio and handle new channel mapping
  - Update tests to reflect new channel assignments
  - Update requirements and design docs to document mono configuration
  - Verify mono process audio on channel 1, microphone on channel 2

- [ ] 38. Add ALAC compression CLI option and argument parsing

- [x] 38.1 Add `--alac`/`-a` flag to `AudioRecorderCLI`
  - Add `@Flag(name: [.customShort("a"), .customLong("alac")], help: "Enable ALAC (Apple Lossless) compression for output files") var enableALAC: Bool = false`
  - Ensure default is `false` and help text describes benefits and output format (`.m4a`)
  - _Requirements: 16.1_

- [x] 38.2 Plumb configuration through the app
  - Add `enableALAC` to runtime configuration/state and pass to recording workflow entry points
  - No behavior change when `false`; this only enables later ALAC steps
  - _Requirements: 16.1_

- [x] 38.3 Validation scaffolding for conflicting compression flags
  - Add guard structure to prevent incompatible compression flags (future-proof); produce clear error when multiple compression modes are selected
  - Unit test this validation with stubbed alternative flag to lock behavior
  - _Requirements: 16.1_

- [x] 38.4 Unit tests for CLI parsing
  - In `CLITests.swift`, add tests verifying: default is `false`, `--alac` sets `true`, short `-a` works, and help text includes ALAC description
  - _Requirements: 16.1_

- [x] 39. Implement ALAC audio format configuration and validation

  - Create ALACConfiguration struct to manage ALAC encoding settings (sample rate, bit depth, channel count)
  - Implement ALAC-compatible AVAudioFormat creation with proper codec settings (kAudioFormatAppleLossless)
  - Add validation for ALAC constraints (maximum 8 channels, supported sample rates, bit depths)
  - Create ALAC settings dictionary with optimal quality parameters (AVEncoderAudioQualityKey: max)
  - Implement format conversion utilities for PCM-to-ALAC encoding preparation
  - Write unit tests for ALAC format configuration and constraint validation

- [ ] 40. Enhance FileController for ALAC file creation and management

  - Add ALAC file creation methods using AVAudioFile with ALAC settings
  - Implement ALAC-specific filename generation with .m4a extension for better compatibility
  - Create ALAC file writing methods that handle multi-channel audio (up to 8 channels)
  - Add ALAC file size monitoring and compression ratio reporting
  - Implement proper error handling for ALAC encoding failures and fallback to uncompressed
  - Write unit tests for ALAC file creation, writing, and error handling scenarios

- [ ] 41. Update AudioProcessor for ALAC-compatible audio processing

  - Modify audio buffer processing to ensure ALAC-compatible PCM format (interleaved Int16/Int24)
  - Implement audio format conversion from Float32 (ScreenCaptureKit) to ALAC-compatible formats
  - Add buffer management optimizations for ALAC encoding (larger buffers for better compression)
  - Create audio quality preservation checks to ensure lossless encoding
  - Implement real-time compression ratio monitoring and performance metrics
  - Write unit tests for ALAC audio processing and format conversion accuracy

- [ ] 42. Integrate ALAC encoding with AudioCapturer workflow

  - Modify AudioCapturer to support ALAC output alongside existing CAF output
  - Implement conditional ALAC file creation based on CLI flag in recording workflow
  - Add ALAC encoding to both single-channel (process-only) and multi-channel (with inputs) recording modes
  - Create ALAC-specific audio buffer handling and writing in real-time capture loop
  - Implement ALAC encoding performance monitoring and CPU usage tracking
  - Add graceful fallback to uncompressed CAF if ALAC encoding fails during recording
  - Write integration tests for ALAC-enabled recording workflows

- [ ] 43. Add ALAC compression performance optimization and monitoring

  - Implement background thread processing for ALAC encoding to minimize audio dropouts
  - Add ALAC compression ratio calculation and real-time reporting to user
  - Create buffer size optimization for ALAC encoding efficiency vs. latency trade-offs
  - Implement memory usage monitoring for ALAC encoding buffers and cleanup
  - Add ALAC encoding speed benchmarking and performance warnings for slow systems
  - Create compression statistics logging (original size, compressed size, ratio, encoding time)
  - Write performance tests for ALAC encoding under various system loads

- [ ] 44. Update error handling and user guidance for ALAC compression

  - Add ALAC-specific error types and localized error messages
  - Implement user guidance for ALAC encoding failures and system requirements
  - Create fallback mechanisms when ALAC encoding is not available or fails
  - Add ALAC compatibility warnings for older macOS versions or unsupported configurations
  - Implement ALAC file validation and corruption detection
  - Create user notifications for compression ratio achievements and file size savings
  - Write unit tests for ALAC error handling and user guidance scenarios

- [ ] 45. Add comprehensive ALAC testing and validation

  - Create integration tests for ALAC-compressed file creation and playback verification
  - Implement ALAC compression ratio validation tests (ensure 40-60% size reduction)
  - Add multi-channel ALAC encoding tests with channel mapping verification
  - Create ALAC file format validation tests using AVAudioFile reading
  - Implement ALAC vs. uncompressed audio quality comparison tests (bit-perfect verification)
  - Add ALAC performance benchmarking tests for encoding speed and CPU usage
  - Create end-to-end ALAC workflow tests combining process audio and input device capture
  - Write ALAC compatibility tests for various macOS versions and hardware configurations

- [ ] 46. Update documentation and finalize ALAC compression feature

  - Update README.md with comprehensive ALAC compression documentation and benefits
  - Document ALAC file format specifications and compatibility requirements
  - Add usage examples showing --alac flag with various recording scenarios
  - Document ALAC compression ratios, performance characteristics, and system requirements
  - Include ALAC troubleshooting section for encoding failures and performance issues
  - Update command-line help with ALAC-specific options and recommendations
  - Create ALAC vs. uncompressed comparison guide for users
  - Verify all ALAC-related code documentation and comments are comprehensive
  - Run final integration tests to ensure ALAC feature works with all existing functionality
 