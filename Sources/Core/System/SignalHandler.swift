import Foundation

public final class SignalHandler {
    private var source: DispatchSourceSignal?
    private let signalNumber: Int32
    private let queue: DispatchQueue

    public init(signalNumber: Int32 = SIGINT, queue: DispatchQueue = .main) {
        self.signalNumber = signalNumber
        self.queue = queue
    }

    public func start(onSignal: @escaping () -> Void) {
        // Ensure default disposition doesn't terminate and allow GCD to receive it
        signal(signalNumber, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: signalNumber, queue: queue)
        src.setEventHandler {
            onSignal()
        }
        src.resume()
        self.source = src
    }

    public func stop() {
        source?.cancel()
        source = nil
    }
}
