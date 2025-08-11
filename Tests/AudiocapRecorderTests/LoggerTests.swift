import XCTest
@testable import AudiocapRecorder

private final class BufferSink: LogSink {
    var messages: [String] = []
    func write(_ message: String) { messages.append(message) }
}

final class LoggerTests: XCTestCase {
    func testDebugGatedByVerbose() {
        let sink = BufferSink()
        let logger = Logger(verbose: false, sink: sink)
        logger.debug("hidden")
        logger.info("shown")
        XCTAssertEqual(sink.messages, ["shown"]) // debug suppressed

        let sink2 = BufferSink()
        let logger2 = Logger(verbose: true, sink: sink2)
        logger2.debug("visible")
        XCTAssertEqual(sink2.messages.first, "DEBUG: visible")
    }
}
