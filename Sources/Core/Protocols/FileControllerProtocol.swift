import Foundation

public protocol FileControllerProtocol {
    func createOutputDirectory(_ path: String) throws
    func generateTimestampedFilename() -> String
    func writeAudioData(_ data: Data, to directory: String) throws -> URL
    func defaultOutputDirectory() -> URL

    func writeMultiChannelAudioData(_ data: Data, to directory: String) throws -> URL
    func writeChannelMappingLog(_ mappingJSON: Data, to directory: String, baseFilename: String) throws -> URL
}
