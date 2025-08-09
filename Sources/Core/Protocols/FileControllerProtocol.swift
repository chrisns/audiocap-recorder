import Foundation

public protocol FileControllerProtocol {
    func createOutputDirectory(_ path: String) throws
    func generateTimestampedFilename() -> String
    func writeAudioData(_ data: Data, to directory: String) throws -> URL
}
