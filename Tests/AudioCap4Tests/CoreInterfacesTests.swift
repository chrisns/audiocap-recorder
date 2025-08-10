import XCTest
import AVFoundation
@testable import AudioCap4

final class CoreInterfacesTests: XCTestCase {
    func testGenerateTimestampedFilenameFormat() throws {
        // Format: yyyy-MM-dd-HH-mm-ss.<ext>
        let fc = TestFileController()
        let name = fc.generateTimestampedFilename(extension: "wav")
        let pattern = #"^\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}\.wav$"#
        XCTAssertNotNil(name.range(of: pattern, options: .regularExpression))
    }
}

private final class TestFileController: FileControllerProtocol {
    func createOutputDirectory(_ path: String) throws {}
    func generateTimestampedFilename(extension ext: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.string(from: Date()) + "." + ext
    }
    func writeAudioData(_ data: Data, to directory: String) throws -> URL {
        return URL(fileURLWithPath: directory).appendingPathComponent(generateTimestampedFilename(extension: "caf"))
    }
    func defaultOutputDirectory() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }
    func writeMultiChannelAudioData(_ data: Data, to directory: String) throws -> URL {
        return try writeAudioData(data, to: directory)
    }
    func writeChannelMappingLog(_ mappingJSON: Data, to directory: String, baseFilename: String) throws -> URL {
        return URL(fileURLWithPath: directory).appendingPathComponent("test-channels.json")
    }
    func writeWAVBuffer(_ buffer: AVAudioPCMBuffer, to directory: String, bitDepth: Int) throws -> URL {
        return try writeAudioData(Data(), to: directory)
    }
    func writeCAFBuffer(_ buffer: AVAudioPCMBuffer, to directory: String) throws -> URL {
        return try writeAudioData(Data(), to: directory)
    }
}
