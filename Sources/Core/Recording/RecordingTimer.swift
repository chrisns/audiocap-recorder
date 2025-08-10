import Foundation

public final class RecordingTimer {
    public typealias TickHandler = (_ elapsedSeconds: Int) -> Void
    public typealias CompletionHandler = () -> Void

    private let queue: DispatchQueue
    private let tickInterval: TimeInterval
    private let maxDurationSeconds: Int

    private var startDate: Date?
    private var timer: DispatchSourceTimer?
    private var isRunning: Bool = false

    public init(queue: DispatchQueue = .main, tickInterval: TimeInterval = 1.0, maxDurationSeconds: Int) {
        self.queue = queue
        self.tickInterval = tickInterval
        self.maxDurationSeconds = maxDurationSeconds
    }

    public func start(onTick: @escaping TickHandler, onCompleted: @escaping CompletionHandler) {
        stop()
        startDate = Date()
        isRunning = true
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + tickInterval, repeating: tickInterval)
        t.setEventHandler { [weak self] in
            guard let self = self, self.isRunning, let start = self.startDate else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            onTick(elapsed)
            if elapsed >= self.maxDurationSeconds {
                self.stop()
                onCompleted()
            }
        }
        timer = t
        t.resume()
    }

    public func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
        startDate = nil
    }
}
