# Project Structure

## Swift Package Manager Layout
```
AudioRecorder/
├── Package.swift                 # SPM package definition
├── README.md                     # Project documentation
├── Sources/
│   └── AudioRecorder/
│       ├── main.swift           # Application entry point
│       ├── CLI/
│       │   └── AudioRecorderCLI.swift    # ArgumentParser CLI interface
│       ├── Core/
│       │   ├── ProcessManager.swift      # Process discovery & monitoring
│       │   ├── AudioCapturer.swift       # ScreenCaptureKit integration
│       │   ├── AudioProcessor.swift      # Audio filtering & processing
│       │   └── FileController.swift      # File I/O operations
│       ├── Models/
│       │   ├── ProcessInfo.swift         # Process data structures
│       │   ├── RecordingSession.swift    # Recording state management
│       │   └── AudioConfiguration.swift  # Audio settings
│       ├── Protocols/
│       │   ├── ProcessManagerProtocol.swift
│       │   ├── AudioCapturerProtocol.swift
│       │   └── FileControllerProtocol.swift
│       └── Utils/
│           ├── PermissionManager.swift   # macOS permissions handling
│           └── AudioRecorderError.swift  # Error definitions
├── Tests/
│   └── AudioRecorderTests/
│       ├── CLITests.swift               # CLI argument parsing tests
│       ├── ProcessManagerTests.swift    # Process discovery tests
│       ├── AudioProcessorTests.swift    # Audio processing tests
│       ├── FileControllerTests.swift    # File operations tests
│       └── Mocks/
│           ├── MockProcessManager.swift
│           ├── MockAudioCapturer.swift
│           └── MockFileController.swift
└── .github/
    └── workflows/
        └── ci.yml                       # GitHub Actions CI/CD
```

## Component Organization

### Core Components (`Sources/AudioRecorder/Core/`)
- **ProcessManager**: Handles process discovery using NSRunningApplication and regex matching
- **AudioCapturer**: Manages ScreenCaptureKit audio capture and SCStreamDelegate implementation
- **AudioProcessor**: Processes audio buffers, correlates with process activity, converts to WAV
- **FileController**: Manages output directories, timestamped filenames, and file writing

### CLI Layer (`Sources/AudioRecorder/CLI/`)
- **AudioRecorderCLI**: Main command interface using Swift ArgumentParser
- Handles argument validation, permission checks, and user feedback

### Data Models (`Sources/AudioRecorder/Models/`)
- **ProcessInfo**: Process metadata and activity tracking
- **RecordingSession**: Recording state and session management
- **AudioConfiguration**: Audio capture settings and limits

### Protocols (`Sources/AudioRecorder/Protocols/`)
- Define interfaces for all major components to enable testing and modularity
- Support dependency injection and mock implementations

### Utilities (`Sources/AudioRecorder/Utils/`)
- **PermissionManager**: macOS permission handling and user guidance
- **AudioRecorderError**: Comprehensive error types and localized messages

## File Naming Conventions
- **Swift files**: PascalCase (e.g., `ProcessManager.swift`)
- **Protocol files**: PascalCase with "Protocol" suffix (e.g., `ProcessManagerProtocol.swift`)
- **Test files**: PascalCase with "Tests" suffix (e.g., `ProcessManagerTests.swift`)
- **Mock files**: PascalCase with "Mock" prefix (e.g., `MockProcessManager.swift`)

## Output Structure
- **Default recordings**: `~/Documents/audiocap/`
- **Filename format**: `yyyy-MM-dd-HH-mm-ss.wav`
- **Build artifacts**: `.build/` (SPM generated, gitignored)

## Configuration Files
- **Package.swift**: Dependencies, targets, and build configuration
- **ci.yml**: GitHub Actions workflow for automated testing and builds
- **.gitignore**: Standard Swift/Xcode ignore patterns plus `.build/` and `DerivedData/`



## Development Workflow

1. **Research First**: Use Context7 MCP to understand current library APIs and best practices
2. **Install Dependencies**: Run `pnpm install` for frontend, then `cargo build` for backend
3. **Verify Tests Pass**: Run `cargo test` first, then `pnpm test` to establish baseline
4. **Development**: Use `pnpm tauri dev` for hot-reload development
5. **Continuous Testing**: Run relevant tests frequently during implementation
6. **Final Verification**: All tests must pass before task completion
7. **Linting**: Run linting tools first to auto reformat code first before having before commits
8. **Git Commit**: **REQUIRED** - Commit all changes with a meaningful message describing what was accomplished

## Git Commit Requirements

**CRITICAL**: Every task completion must include a git commit with a descriptive message.

### Commit Message Format

Use clear, descriptive commit messages that explain what was accomplished:

```bash
# Good examples (run commands individually):
git add -A
git commit -m "Implement audio device enumeration with hot-swap detection"

git add -A
git commit -m "Add Chrome tab trigger detection with regex configuration"

git add -A
git commit -m "Fix audio stream synchronization during device reconnection"

git add -A
git commit -m "Update settings UI with trigger configuration forms"

# Bad examples (avoid):
git commit -m "fix bug"
git commit -m "update code"
git commit -m "changes"
```

### Commit Workflow

**IMPORTANT**: Always run commands individually, never chain with `&&` or other operators.

1. **Stage All Changes**: `git add -A` to include all modified, new, and deleted files
2. **Commit with Message**: `git commit -m "Descriptive message of what was accomplished"`
3. **Verify Commit**: `git log --oneline -1` to confirm the commit was created

### Command Execution Guidelines

- **Run commands individually**: Execute each command separately for better tracking and error handling
- **Avoid command chaining**: Never use `&&`, `||`, `;`, or other command separators
- **Allow command listing**: Individual commands enable better execution monitoring and debugging

### What to Include in Commits

- All source code changes (Rust, TypeScript, configuration files)
- Test updates and new test files
- Documentation updates
- Configuration changes (Cargo.toml, package.json, etc.)
- Any generated files that should be tracked

**No task is complete without a proper git commit.**
