import XCTest
@testable import AudioCap4

final class CoreInterfacesTests: XCTestCase {
    func testGenerateTimestampedFilenameFormat() throws {
        // Format: yyyy-MM-dd-HH-mm-ss.wav
        let fc = TestFileController()
        let name = fc.generateTimestampedFilename()
        let pattern = #"^\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}\.wav$"#
        XCTAssertNotNil(name.range(of: pattern, options: .regularExpression))
    }
}

private final class TestFileController: FileControllerProtocol {
    func createOutputDirectory(_ path: String) throws {}
    func generateTimestampedFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.string(from: Date()) + ".wav"
    }
    func writeAudioData(_ data: Data, to directory: String) throws -> URL {
        return URL(fileURLWithPath: directory).appendingPathComponent(generateTimestampedFilename())
    }
    func defaultOutputDirectory() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }
}
