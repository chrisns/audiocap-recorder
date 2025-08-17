# Requirements Document

## Introduction

This feature involves creating a command-line macOS application that can record system audio output and filter it to capture audio from specific running processes or applications. The application will use ScreenCaptureKit to capture all system audio, identify target processes using regular expression matching against process names, correlate audio activity with process activity, and save the filtered recordings as CAF files with timestamped filenames to a configurable directory.

## Requirements

### Requirement 1

**User Story:** As a developer, I want to record audio from specific applications by providing a regex pattern, so that I can capture audio from processes without manually identifying their exact names.

#### Acceptance Criteria

1. WHEN the application is launched with a regex pattern THEN the system SHALL identify all currently running processes that match the pattern against both executable name and full process path
2. WHEN multiple processes match the regex THEN the system SHALL record audio from all matching processes and mix them into a single recording
3. WHEN no processes match the regex THEN the system SHALL display an error message and exit gracefully
4. WHEN a matching process terminates during recording THEN the system SHALL continue recording from remaining matching processes

### Requirement 2

**User Story:** As a user, I want recordings to be automatically saved with timestamped filenames, so that I can easily organize and identify when recordings were made.

#### Acceptance Criteria

1. WHEN a recording starts THEN the system SHALL create a CAF file with the format "yyyy-mm-dd-hh-mm-ss.caf"
2. WHEN no output directory is specified THEN the system SHALL save files to "~/Documents/audiocap/"
3. WHEN a custom output directory is specified THEN the system SHALL save files to the specified location
4. WHEN the output directory doesn't exist THEN the system SHALL create the directory structure automatically

### Requirement 3

**User Story:** As a user, I want to specify a custom output directory at runtime, so that I can organize recordings according to my workflow.

#### Acceptance Criteria

1. WHEN the application is launched with an output directory parameter THEN the system SHALL use that directory for saving recordings
2. WHEN the specified directory path is invalid THEN the system SHALL display an error message and exit
3. WHEN the specified directory requires creation THEN the system SHALL create the necessary directory structure
4. WHEN the user has insufficient permissions for the directory THEN the system SHALL display a permission error

### Requirement 4

**User Story:** As a user, I want the application to work with processes that are already running, so that I don't need to restart applications to begin recording.

#### Acceptance Criteria

1. WHEN the application starts THEN the system SHALL scan all currently running processes and begin capturing system audio via ScreenCaptureKit
2. WHEN a process matching the regex is found THEN the system SHALL monitor that process for audio activity and correlate it with captured system audio
3. WHEN the system cannot access ScreenCaptureKit THEN the system SHALL display a clear error message about required screen recording permissions
4. WHEN no screen recording permissions are granted THEN the system SHALL display step-by-step instructions for enabling permissions in System Preferences

### Requirement 5

**User Story:** As a user, I want clear command-line interface options, so that I can easily configure the recording behavior.

#### Acceptance Criteria

1. WHEN the application is run without arguments THEN the system SHALL display usage instructions
2. WHEN invalid arguments are provided THEN the system SHALL display helpful error messages and usage examples
3. WHEN the help flag is used THEN the system SHALL display all available options and their descriptions
4. WHEN the application starts successfully THEN the system SHALL display confirmation of recording parameters and matched processes

### Requirement 6

**User Story:** As a user, I want to gracefully stop recording, so that I can control when the recording session ends.

#### Acceptance Criteria

1. WHEN the user sends SIGINT (Ctrl+C) THEN the system SHALL stop recording and save the current file
2. WHEN the recording is stopped THEN the system SHALL display the location of the saved file
3. WHEN the application terminates unexpectedly THEN the system SHALL attempt to save any recorded audio data
4. WHEN multiple processes are being recorded THEN the system SHALL stop all recordings simultaneously

### Requirement 7

**User Story:** As a developer, I want automated testing and build processes using GitHub Actions, so that I can ensure code quality and reliable releases.

#### Acceptance Criteria

1. WHEN code is committed THEN the system SHALL run automated unit tests via GitHub Actions CI pipeline
2. WHEN tests pass THEN the system SHALL build the application for macOS distribution using GitHub Actions
3. WHEN a release is tagged THEN the system SHALL create distributable binaries automatically via GitHub Actions
4. WHEN tests fail THEN the system SHALL prevent merging and notify developers of failures through GitHub Actions
5. WHEN the build process runs THEN the system SHALL validate that all dependencies are available and compatible on macOS runners

### Requirement 8

**User Story:** As a developer, I want comprehensive test coverage, so that I can confidently make changes without breaking functionality.

#### Acceptance Criteria

1. WHEN unit tests are run THEN the system SHALL test process discovery and regex matching logic
2. WHEN integration tests are run THEN the system SHALL test audio capture functionality with mock processes
3. WHEN file system tests are run THEN the system SHALL test directory creation and file saving operations
4. WHEN error handling tests are run THEN the system SHALL verify graceful handling of permission errors and invalid inputs
5. WHEN the test suite runs THEN the system SHALL achieve at least 80% code coverage

### Requirement 9

**User Story:** As a user, I want recording duration limits and real-time feedback, so that I can monitor recording progress and prevent excessive file sizes.

#### Acceptance Criteria

1. WHEN a recording starts THEN the system SHALL display the current recording duration in real-time
2. WHEN a recording reaches 12 hours THEN the system SHALL automatically stop recording and save the file
3. WHEN recording is active THEN the system SHALL update the duration display every second
4. WHEN the recording stops THEN the system SHALL display the final duration and file location

### Requirement 10

**User Story:** As a user, I want the system to handle macOS screen recording permissions properly, so that I can set up the application correctly for ScreenCaptureKit audio capture.

#### Acceptance Criteria

1. WHEN the application starts without screen recording permissions THEN the system SHALL display clear instructions for granting ScreenCaptureKit permissions
2. WHEN screen recording permissions are denied THEN the system SHALL provide step-by-step guidance to enable them in System Preferences > Privacy & Security > Screen Recording
3. WHEN permissions are granted THEN the system SHALL proceed with ScreenCaptureKit audio capture
4. WHEN permission status changes during runtime THEN the system SHALL detect and respond appropriately

### Requirement 11

**User Story:** As a user, I want the system to intelligently filter captured system audio to isolate audio from target processes, so that I get clean recordings without unrelated system sounds.

#### Acceptance Criteria

1. WHEN system audio is captured THEN the system SHALL monitor process activity to correlate audio with target processes
2. WHEN target processes are active and generating audio THEN the system SHALL include that audio in the recording
3. WHEN non-target processes generate audio THEN the system SHALL attempt to filter out that audio from the recording
4. WHEN audio correlation is uncertain THEN the system SHALL include the audio but log a warning about potential mixed sources

### Requirement 12

**User Story:** As a user, I want to capture all available audio input devices simultaneously with the process audio, so that I can record comprehensive audio sessions that include microphones, line inputs, and other audio sources alongside application audio.

#### Acceptance Criteria

1. WHEN the --capture-inputs CLI option is provided THEN the system SHALL enumerate and capture from all available audio input devices
2. WHEN audio input devices are captured THEN the system SHALL create an 8-channel CAF file with mono process audio on channel 1 and mono input devices on channels 2-8
3. WHEN fewer than 7 input devices are available THEN the system SHALL leave unused channels silent in the 8-channel file
4. WHEN more than 7 input devices are available THEN the system SHALL capture the first 7 devices and log a warning about additional devices being ignored

### Requirement 13

**User Story:** As a user, I want the system to handle audio input device hot-swapping during recording, so that I can connect/disconnect devices like Bluetooth headphones or unplug my laptop without interrupting the recording session.

#### Acceptance Criteria

1. WHEN an audio input device is connected during recording THEN the system SHALL detect the new device and assign it to the next available channel (3-8)
2. WHEN an audio input device is disconnected during recording THEN the system SHALL continue recording with remaining devices and mark the disconnected channel as silent
3. WHEN a previously disconnected device reconnects THEN the system SHALL reassign it to an available channel and resume capturing its audio
4. WHEN device changes occur THEN the system SHALL log device connection/disconnection events with timestamps for reference

### Requirement 14

**User Story:** As a user, I want clear channel mapping information in the output, so that I can identify which audio sources correspond to which channels in the 8-channel recording.

#### Acceptance Criteria

1. WHEN recording starts with input capture enabled THEN the system SHALL display a channel mapping showing which devices are assigned to channels 3-8
2. WHEN device changes occur during recording THEN the system SHALL update and display the current channel mapping
3. WHEN recording completes THEN the system SHALL save a channel mapping log file alongside the CAF file with device assignments and timing information
4. WHEN no input devices are available THEN the system SHALL clearly indicate that only process audio (channels 1-2) will be recorded

### Requirement 15

**User Story:** As a user, I want the system to filter out aggregate and virtual audio interfaces during input device enumeration, so that I only capture from physical audio input devices and avoid potential audio routing issues or duplicate captures.

#### Acceptance Criteria

1. WHEN enumerating audio input devices THEN the system SHALL exclude aggregate audio devices from the available device list
2. WHEN enumerating audio input devices THEN the system SHALL exclude virtual audio interfaces (such as software-created devices) from the available device list
3. WHEN filtering devices THEN the system SHALL only include physical audio input devices such as built-in microphones, USB audio interfaces, and hardware-based audio devices
4. WHEN aggregate or virtual devices are detected THEN the system SHALL log their exclusion for debugging purposes but not display them to the user

### Requirement 16

**User Story:** As a user, I want the option to enable ALAC (Apple Lossless Audio Codec) compression for my recordings, so that I can significantly reduce file sizes while maintaining perfect audio quality for long recording sessions.

#### Acceptance Criteria

1. WHEN the --alac CLI flag is provided THEN the system SHALL encode all audio output using ALAC compression instead of uncompressed CAF
2. WHEN ALAC compression is enabled THEN the system SHALL create .m4a files with ALAC encoding that are 40-60% smaller than uncompressed equivalents
3. WHEN ALAC compression is used THEN the system SHALL maintain bit-perfect lossless audio quality identical to the original uncompressed audio
4. WHEN ALAC encoding fails THEN the system SHALL gracefully fallback to uncompressed CAF recording and notify the user of the fallback

### Requirement 17

**User Story:** As a user, I want ALAC compression to work seamlessly with multi-channel recording, so that I can benefit from reduced file sizes even when capturing multiple input devices simultaneously.

#### Acceptance Criteria

1. WHEN ALAC compression is enabled with --capture-inputs THEN the system SHALL create multi-channel ALAC files supporting up to 8 channels
2. WHEN multi-channel ALAC recording is active THEN the system SHALL maintain proper channel mapping and assignment for all input devices
3. WHEN ALAC multi-channel encoding occurs THEN the system SHALL preserve audio quality and channel separation identical to uncompressed multi-channel recording
4. WHEN multi-channel ALAC files are created THEN the system SHALL generate corresponding channel mapping logs alongside the compressed audio files

### Requirement 18

**User Story:** As a user, I want real-time feedback about ALAC compression performance and file size savings, so that I can monitor the effectiveness of compression during recording sessions.

#### Acceptance Criteria

1. WHEN ALAC recording is active THEN the system SHALL display real-time compression ratio and estimated file size savings
2. WHEN ALAC encoding experiences performance issues THEN the system SHALL warn the user about potential audio dropouts or encoding delays
3. WHEN ALAC recording completes THEN the system SHALL report final compression statistics including original size, compressed size, and compression ratio
4. WHEN ALAC compression achieves significant savings THEN the system SHALL notify the user of the file size reduction percentage

### Requirement 19

**User Story:** As a user, I want robust error handling and fallback mechanisms for ALAC compression, so that my recording sessions are never interrupted by compression failures.

#### Acceptance Criteria

1. WHEN ALAC encoding fails during recording THEN the system SHALL automatically switch to uncompressed CAF recording without stopping the session
2. WHEN ALAC compression is not supported on the system THEN the system SHALL display a clear error message and suggest using uncompressed recording
3. WHEN ALAC encoding encounters CPU performance issues THEN the system SHALL provide options to reduce compression quality or disable compression
4. WHEN ALAC file creation fails THEN the system SHALL attempt to save the audio in uncompressed format and notify the user of the format change
