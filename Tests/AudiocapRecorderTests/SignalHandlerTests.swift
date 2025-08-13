import XCTest
 import Core

final class SignalHandlerTests: XCTestCase {
    func testSignalHandlerReceivesSignal() async {
        let handler = SignalHandler(signalNumber: SIGUSR1, queue: .main)
        let exp = expectation(description: "signal received")
        handler.start {
            exp.fulfill()
        }
        // Send SIGUSR1 to current process
        kill(getpid(), SIGUSR1)
        await fulfillment(of: [exp], timeout: 1.0)
        handler.stop()
    }
}
