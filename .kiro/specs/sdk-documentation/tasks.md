# Implementation Plan

- [x] 1. Establish documentation infrastructure
  - Create `Docs/` directory with DocC-compatible templates for guides and recipes
  - Add a SwiftPM DocC plugin (`DocGenPlugin`) in `Package.swift`
  - _Requirements: Requirement 2 AC1, Requirement 1 AC1_

- [x] 1.1 Configure API reference generation
  - Implement `docGen` plugin script to invoke `swift package generate-documentation`
  - Output HTML/JSON to `build/docs`
  - _Requirements: Requirement 2 AC1, Requirement 2 AC3_

- [x] 1.2 Integrate search indexing
  - Add Node script to convert JSON docs to lunr.js index (<200 ms search)
  - _Requirements: Requirement 2 AC2_

- [x] 2. Build static site with Docusaurus
  - Scaffold `docs-site/` project with Docusaurus MDX support
  - Import generated DocC bundles and Markdown guides
  - _Requirements: Requirement 2 AC1, Requirement 3 AC1_

- [x] 2.1 Implement versioned docs routing
  - Configure Docusaurus versioning and create `/versions.json` manifest
  - _Requirements: Requirement 4 AC1, Requirement 4 AC2_

- [x] 2.2 Add version switcher widget
  - JavaScript widget reads manifest and rewrites links
  - _Requirements: Requirement 4 AC2, Requirement 4 AC3_

- [x] 3. Create Quick-Start sample project
  - SwiftPM project demonstrating minimal recording setup
  - Ensure it compiles & records to file
  - _Requirements: Requirement 1 AC2, Requirement 5 AC1_

- [x] 3.1 Write Quick-Start guide
  - Markdown tutorial referencing sample project and expected output
  - _Requirements: Requirement 1 AC1, Requirement 1 AC3_

- [x] 4. Create integration recipe samples
  - Mono recording, multichannel, adaptive bitrate streaming projects
  - _Requirements: Requirement 3 AC1, Requirement 5 AC1_

- [x] 4.1 Author recipe guides with annotated code
  - Include prerequisites and step-by-step explanations
  - _Requirements: Requirement 3 AC1, Requirement 3 AC2_

- [x] 5. Add CI workflow `.github/workflows/docs.yml`
  - Job matrix builds sample projects (macOS, iOS) and generates docs
  - Fail build on compilation errors or dead links
  - _Requirements: Requirement 5 AC1, Requirement 5 AC2_

- [x] 5.1 Integrate snippet compilation tests
  - Pass `--analyze` flag to DocC to validate fenced Swift blocks
  - _Requirements: Requirement 5 AC1, Requirement 5 AC3_

- [x] 5.2 Deploy static site to GitHub Pages
  - Publish to `/docs/<tag>` and update `/docs/latest` alias
  - _Requirements: Requirement 4 AC1_

- [x] 6. Update project README
  - Add badge and link to Quick-Start docs
  - _Requirements: Requirement 1 AC1_
