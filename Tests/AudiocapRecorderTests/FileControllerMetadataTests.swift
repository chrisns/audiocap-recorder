import XCTest
 import Core

final class FileControllerMetadataTests: XCTestCase {
    func testWriteSessionMetadataCreatesJSONFile() throws {
        let fc = FileController()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fc.createOutputDirectory(dir.path)
        let base = "test.m4a"
        let url = try fc.writeSessionMetadata(["sessionId": UUID().uuidString, "user": "tester"], to: dir.path, baseFilename: base)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(url.lastPathComponent.contains("-session.json"))
    }
}
