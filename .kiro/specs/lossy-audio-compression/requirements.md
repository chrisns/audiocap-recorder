# Requirements Document

## Introduction

This feature adds lossy audio compression capabilities to the Audio Process Recorder application. Building upon the existing ALAC (lossless) compression support, this feature will provide users with AAC and MP3 compression options that significantly reduce file sizes while maintaining acceptable audio quality. The feature will include configurable bitrate settings, quality presets, and comprehensive CLI options to give users full control over the compression trade-offs between file size and audio quality.

## Requirements

### Requirement 1

**User Story:** As a user, I want to compress my recordings using AAC format with configurable bitrates, so that I can achieve optimal file size reduction while maintaining high audio quality for my specific use case.

#### Acceptance Criteria

1. WHEN the --aac CLI flag is provided THEN the system SHALL encode all audio output using AAC compression instead of uncompressed CAF or ALAC
2. WHEN AAC compression is enabled THEN the system SHALL create .m4a files with AAC encoding that are 70-90% smaller than uncompressed equivalents
3. WHEN AAC bitrate is not specified THEN the system SHALL use 128 kbps as the default bitrate for optimal quality-to-size ratio
4. WHEN AAC encoding fails THEN the system SHALL gracefully fallback to uncompressed CAF recording and notify the user of the fallback

### Requirement 2

**User Story:** As a user, I want to specify custom bitrates for AAC compression ranging from 64 kbps to 320 kbps, so that I can fine-tune the balance between file size and audio quality based on my content type and storage constraints.

#### Acceptance Criteria

1. WHEN the --bitrate CLI option is provided with AAC compression THEN the system SHALL use the specified bitrate for encoding (64-320 kbps range)
2. WHEN an invalid bitrate is specified THEN the system SHALL display an error message and suggest valid bitrate ranges
3. WHEN bitrate is set below 64 kbps THEN the system SHALL warn the user about potential quality degradation and use 64 kbps as minimum
4. WHEN bitrate is set above 320 kbps THEN the system SHALL cap the bitrate at 320 kbps and notify the user

### Requirement 3

**User Story:** As a user, I want to compress my recordings using MP3 format for maximum compatibility across different platforms and devices, so that I can share my recordings without worrying about format support.

#### Acceptance Criteria

1. WHEN the --mp3 CLI flag is provided THEN the system SHALL encode all audio output using MP3 compression instead of uncompressed CAF or ALAC
2. WHEN MP3 compression is enabled THEN the system SHALL create .mp3 files with MP3 encoding that are 80-92% smaller than uncompressed equivalents
3. WHEN MP3 bitrate is not specified THEN the system SHALL use 128 kbps as the default bitrate for good quality and compatibility
4. WHEN MP3 encoding fails THEN the system SHALL gracefully fallback to uncompressed CAF recording and notify the user of the fallback

### Requirement 4

**User Story:** As a user, I want quality presets for lossy compression (low, medium, high, maximum), so that I can quickly select appropriate settings without needing to understand technical bitrate details.

#### Acceptance Criteria

1. WHEN the --quality CLI option is provided THEN the system SHALL apply predefined bitrate and encoder settings based on the quality level
2. WHEN quality is set to "low" THEN the system SHALL use 64 kbps bitrate for maximum file size reduction
3. WHEN quality is set to "medium" THEN the system SHALL use 128 kbps bitrate for balanced quality and size
4. WHEN quality is set to "high" THEN the system SHALL use 192 kbps bitrate for high-quality compression
5. WHEN quality is set to "maximum" THEN the system SHALL use 256 kbps bitrate for near-transparent quality

### Requirement 5

**User Story:** As a user, I want lossy compression to work seamlessly with multi-channel recording, so that I can benefit from reduced file sizes even when capturing multiple input devices simultaneously.

#### Acceptance Criteria

1. WHEN lossy compression is enabled with --capture-inputs THEN the system SHALL create multi-channel compressed files supporting up to 8 channels
2. WHEN multi-channel lossy recording is active THEN the system SHALL maintain proper channel mapping and assignment for all input devices
3. WHEN lossy multi-channel encoding occurs THEN the system SHALL preserve channel separation and audio quality according to the selected compression settings
4. WHEN multi-channel lossy files are created THEN the system SHALL generate corresponding channel mapping logs alongside the compressed audio files

### Requirement 6

**User Story:** As a user, I want real-time feedback about lossy compression performance and file size savings, so that I can monitor the effectiveness of compression during recording sessions.

#### Acceptance Criteria

1. WHEN lossy recording is active THEN the system SHALL display real-time compression ratio and estimated file size savings
2. WHEN lossy encoding experiences performance issues THEN the system SHALL warn the user about potential audio dropouts or encoding delays
3. WHEN lossy recording completes THEN the system SHALL report final compression statistics including original size, compressed size, and compression ratio
4. WHEN lossy compression achieves significant savings THEN the system SHALL notify the user of the file size reduction percentage

### Requirement 7

**User Story:** As a user, I want robust error handling and fallback mechanisms for lossy compression, so that my recording sessions are never interrupted by compression failures.

#### Acceptance Criteria

1. WHEN lossy encoding fails during recording THEN the system SHALL automatically switch to uncompressed CAF recording without stopping the session
2. WHEN lossy compression is not supported on the system THEN the system SHALL display a clear error message and suggest using uncompressed recording
3. WHEN lossy encoding encounters CPU performance issues THEN the system SHALL provide options to reduce compression quality or disable compression
4. WHEN lossy file creation fails THEN the system SHALL attempt to save the audio in uncompressed format and notify the user of the format change

### Requirement 8

**User Story:** As a user, I want validation to prevent conflicting compression options, so that I don't accidentally specify multiple compression formats simultaneously.

#### Acceptance Criteria

1. WHEN multiple compression flags are specified (--alac, --aac, --mp3) THEN the system SHALL display an error message indicating only one compression format can be selected
2. WHEN compression format conflicts are detected THEN the system SHALL provide clear guidance on valid compression option combinations
3. WHEN --bitrate is specified without a compression format THEN the system SHALL display an error message requiring a lossy compression format
4. WHEN --quality is specified without a compression format THEN the system SHALL display an error message requiring a lossy compression format

### Requirement 9

**User Story:** As a user, I want comprehensive CLI help and documentation for lossy compression options, so that I can understand all available settings and make informed choices about compression parameters.

#### Acceptance Criteria

1. WHEN the help flag is used THEN the system SHALL display detailed information about all lossy compression options and their effects
2. WHEN compression options are displayed THEN the system SHALL include examples of typical use cases and recommended settings
3. WHEN invalid compression parameters are provided THEN the system SHALL display helpful error messages with suggested corrections
4. WHEN compression format help is requested THEN the system SHALL explain the differences between AAC, MP3, and lossless formats

### Requirement 10

**User Story:** As a user, I want lossy compression to maintain compatibility with existing recording workflows, so that I can use compression options alongside all current features without disruption.

#### Acceptance Criteria

1. WHEN lossy compression is enabled THEN the system SHALL work seamlessly with process regex matching and audio filtering
2. WHEN lossy compression is used with --capture-inputs THEN the system SHALL maintain all input device management and hot-swapping capabilities
3. WHEN lossy compression is active THEN the system SHALL preserve all existing CLI options and recording duration limits
4. WHEN lossy compression is enabled THEN the system SHALL maintain graceful shutdown and signal handling behavior

### Requirement 11

**User Story:** As a user, I want variable bitrate (VBR) encoding options for AAC compression, so that I can achieve optimal quality by allowing the encoder to adjust bitrate based on audio complexity.

#### Acceptance Criteria

1. WHEN the --vbr CLI flag is provided with AAC compression THEN the system SHALL use variable bitrate encoding instead of constant bitrate
2. WHEN VBR encoding is enabled THEN the system SHALL allow the encoder to dynamically adjust bitrate based on audio content complexity
3. WHEN VBR is used with quality presets THEN the system SHALL apply appropriate VBR quality settings corresponding to the selected preset
4. WHEN VBR encoding is active THEN the system SHALL report average bitrate and quality metrics in the final compression statistics

### Requirement 12

**User Story:** As a user, I want sample rate conversion options for lossy compression, so that I can optimize file sizes further by reducing sample rates when high-frequency content is not critical.

#### Acceptance Criteria

1. WHEN the --sample-rate CLI option is provided with lossy compression THEN the system SHALL convert audio to the specified sample rate before compression
2. WHEN sample rate conversion is enabled THEN the system SHALL support common rates: 22050 Hz, 44100 Hz, and 48000 Hz
3. WHEN sample rate is reduced THEN the system SHALL apply appropriate anti-aliasing filtering to prevent artifacts
4. WHEN sample rate conversion fails THEN the system SHALL use the original sample rate and notify the user of the fallback
