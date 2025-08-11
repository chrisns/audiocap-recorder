import XCTest
@testable import AudiocapRecorder

final class CompressionMigrationTests: XCTestCase {
    func testDryRunCreatesOutputFile() throws {
        let migrator = CompressionMigration()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Create a dummy input file
        let input = dir.appendingPathComponent("input.caf")
        try Data([0]).write(to: input)
        let output = dir.appendingPathComponent("out.m4a")
        let url = try migrator.transcode(inputURL: input, to: .aac, bitrateKbps: 128, sampleRate: 44100, channels: 2, outputURL: output, dryRun: true)
        XCTAssertEqual(url, output)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
    }

    func testChainingDryRunProducesMultipleOutputs() throws {
        let chain = CompressionChaining()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let input = dir.appendingPathComponent("in.caf")
        try Data([0]).write(to: input)
        let steps = [
            CompressionChainStep(format: .aac, bitrateKbps: 128, sampleRate: 44100, channels: 2),
            CompressionChainStep(format: .mp3, bitrateKbps: 128, sampleRate: 44100, channels: 2)
        ]
        let urls = try chain.runChain(inputURL: input, steps: steps, outputDirectory: dir, dryRun: true)
        XCTAssertEqual(urls.count, 2)
        for u in urls { XCTAssertTrue(FileManager.default.fileExists(atPath: u.path)) }
    }
}
