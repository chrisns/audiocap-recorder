import XCTest
 import Core
final class RecordingTimerTests: XCTestCase {
    func testTimerTicksAndCompletes() async {
        let expectationCompleted = expectation(description: "completed")
        let queue = DispatchQueue(label: "timer.test")
        let timer = RecordingTimer(queue: queue, tickInterval: 0.05, maxDurationSeconds: 0)
        var ticked = false
        timer.start(onTick: { _ in
            ticked = true
        }, onCompleted: {
            expectationCompleted.fulfill()
        })
        await fulfillment(of: [expectationCompleted], timeout: 1.0)
        XCTAssertTrue(ticked)
    }
}
