import Foundation

/// A value behind a lock, so fakes can record calls from any task. (`Mutex` needs macOS 15.)
public final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value

    public init(_ value: Value) {
        stored = value
    }

    public var value: Value {
        lock.withLock { stored }
    }

    @discardableResult
    public func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        try lock.withLock { try body(&stored) }
    }
}
