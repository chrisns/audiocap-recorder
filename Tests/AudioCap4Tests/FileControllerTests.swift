import XCTest
@testable import AudioCap4

final class FileControllerTests: XCTestCase {
    func testCreateDirectoryAndWriteFile() throws {
        let fc = FileController()
        let tempDir = NSTemporaryDirectory().appending("audiocap-tests-") + UUID().uuidString
        try fc.createOutputDirectory(tempDir)
        let data = "test".data(using: .utf8)!
        let url = try fc.writeAudioData(data, to: tempDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".wav"))
    }

    func testTildeExpansion() throws {
        let fc = FileController()
        let home = NSHomeDirectory()
        let dir = "~/Documents/\(UUID().uuidString)"
        try fc.createOutputDirectory(dir)
        let url = try fc.writeAudioData(Data(), to: dir)
        XCTAssertTrue(url.path.hasPrefix(home))
    }
}
