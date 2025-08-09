import Foundation

public final class RecordingTimer {
    public typealias TickHandler = (_ elapsedSeconds: Int) -> Void
    public typealias CompletionHandler = () -> Void

    private let queue: DispatchQueue
    private let tickInterval: TimeInterval
    private let maxDurationSeconds: Int

    private var startDate: Date?
    private var timer: DispatchSourceTimer?

    public init(queue: DispatchQueue = .main, tickInterval: TimeInterval = 1.0, maxDurationSeconds: Int) {
        self.queue = queue
        self.tickInterval = tickInterval
        self.maxDurationSeconds = maxDurationSeconds
    }

    public func start(onTick: @escaping TickHandler, onCompleted: @escaping CompletionHandler) {
        startDate = Date()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: tickInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self, let start = self.startDate else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            onTick(elapsed)
            if elapsed >= self.maxDurationSeconds {
                self.stop()
                onCompleted()
            }
        }
        self.timer = timer
        timer.resume()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
        startDate = nil
    }
}
