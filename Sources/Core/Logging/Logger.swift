import Foundation

public protocol LogSink {
    func write(_ message: String)
}

public struct ConsoleSink: LogSink {
    public init() {}
    public func write(_ message: String) { print(message) }
}

public final class Logger {
    private let isVerboseEnabled: Bool
    private let sink: LogSink

    public init(verbose: Bool, sink: LogSink = ConsoleSink()) {
        self.isVerboseEnabled = verbose
        self.sink = sink
    }

    public var isVerbose: Bool { isVerboseEnabled }

    public func info(_ message: String) {
        sink.write(message)
    }

    public func warn(_ message: String) {
        sink.write("WARN: " + message)
    }

    public func error(_ message: String) {
        sink.write("ERROR: " + message)
    }

    public func debug(_ message: String) {
        guard isVerboseEnabled else { return }
        sink.write("DEBUG: " + message)
    }
}
