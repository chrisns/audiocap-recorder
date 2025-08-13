import XCTest
import AVFoundation
 import Core
final class MP3EncoderTests: XCTestCase {
    func testInitializeConstraints() {
        let enc = MP3Encoder()
        XCTAssertThrowsError(try enc.initialize(configuration: .init(format: .mp3, bitrate: 192, enableVBR: true, sampleRate: 44100, channelCount: 2, quality: .high)))
        XCTAssertThrowsError(try enc.initialize(configuration: .init(format: .mp3, bitrate: 192, enableVBR: false, sampleRate: 44100, channelCount: 6, quality: .high)))
    }

    func testCreateMP3Settings() {
        let enc = MP3Encoder()
        let s = enc.createMP3Settings(bitrate: 128, sampleRate: 44100, channelCount: 2)
        XCTAssertEqual(s[AVFormatIDKey] as? UInt32, kAudioFormatMPEGLayer3)
        XCTAssertEqual(s[AVEncoderBitRateKey] as? Int, 128_000)
    }

    func testCreateFileAndEncode() throws {
        let enc = MP3Encoder()
        try enc.initialize(configuration: .init(format: .mp3, bitrate: 128, enableVBR: false, sampleRate: 44100, channelCount: 2, quality: .high))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp3")
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        // If platform doesn't support MP3 writing, expect compressionNotSupported
        do {
            _ = try enc.createAudioFile(at: url, format: fmt)
            let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: 512)!
            buf.frameLength = 512
            _ = try enc.encode(buffer: buf)
            _ = try enc.finalize()
        } catch AudioRecorderError.compressionNotSupported {
            // acceptable fallback
        }
    }
}
