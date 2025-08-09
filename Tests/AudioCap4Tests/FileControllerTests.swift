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

    func testWriteMultiChannelAndMappingLog() throws {
        let fc = FileController()
        let tempDir = NSTemporaryDirectory().appending("audiocap-tests-") + UUID().uuidString
        try fc.createOutputDirectory(tempDir)
        let wavData = Data(repeating: 0, count: 1024)
        let wavURL = try fc.writeMultiChannelAudioData(wavData, to: tempDir)
        XCTAssertTrue(wavURL.lastPathComponent.hasSuffix(".wav"))

        let mapping: [String: Any] = [
            "channels": [
                "1": "process",
                "3": "Mic A"
            ]
        ]
        let json = try JSONSerialization.data(withJSONObject: mapping, options: [.prettyPrinted])
        let logURL = try fc.writeChannelMappingLog(json, to: tempDir, baseFilename: wavURL.lastPathComponent)
        XCTAssertTrue(logURL.lastPathComponent.hasSuffix("-channels.json"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: logURL.path))
    }
}
