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

- [ ] 6. Build file management and output system

  - Implement FileController class for directory creation and file operations
  - Create timestamped filename generation (yyyy-MM-dd-HH-mm-ss.wav format)
  - Add WAV file writing with proper audio format headers
  - Implement default and custom output directory handling
  - Write unit tests for file operations and directory management
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4_

- [ ] 7. Add real-time recording feedback and duration limits

  - Implement recording duration tracking and display updates
  - Add 12-hour maximum recording limit with automatic stop
  - Create real-time duration display that updates every second
  - Implement graceful recording termination and file saving
  - Write unit tests for duration tracking and limits
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [ ] 8. Implement graceful shutdown and signal handling

  - Add SIGINT (Ctrl+C) signal handling for clean shutdown
  - Implement proper cleanup of ScreenCaptureKit resources
  - Ensure audio data is saved when recording is interrupted
  - Add final recording summary with file location and duration
  - Write integration tests for shutdown scenarios
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [ ] 9. Create comprehensive error handling and user guidance

  - Implement detailed error messages for all failure scenarios
  - Add step-by-step permission setup instructions
  - Create fallback behaviors for partial failures
  - Implement logging system with verbose mode support
  - Write unit tests for error handling and recovery
  - _Requirements: 1.3, 4.3, 5.2, 10.1, 10.2, 10.3, 10.4_

- [ ] 10. Build testing infrastructure and test coverage

  - Create mock implementations for all protocol interfaces
  - Write comprehensive unit tests for each component
  - Implement integration tests for audio capture workflows
  - Add performance tests for memory usage and CPU impact
  - Ensure 80% code coverage across all modules
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ] 11. Set up GitHub Actions CI/CD pipeline

  - Create GitHub Actions workflow for automated testing
  - Configure macOS runners for ScreenCaptureKit compatibility
  - Add build validation for Swift Package Manager
  - Implement automated binary creation for releases
  - Set up test failure notifications and merge protection
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 12. Integrate all components and implement main application flow
  - Wire together CLI, ProcessManager, AudioCapturer, AudioProcessor, and FileController
  - Implement complete recording session lifecycle
  - Add proper resource cleanup and memory management
  - Create end-to-end integration tests
  - Verify all requirements are met through comprehensive testing
  - _Requirements: All requirements integration and validation_
