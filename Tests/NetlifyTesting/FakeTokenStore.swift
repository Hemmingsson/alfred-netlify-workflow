import NetlifyCore

/// A TokenStore in memory.
public final class FakeTokenStore: TokenStore {
    private let token: Locked<String?>

    public init(token: String? = nil) {
        self.token = Locked(token)
    }

    public var current: String? { token.value }

    public func read() throws -> String? { token.value }

    public func save(_ token: String) throws { self.token.withLock { $0 = token } }

    public func delete() throws { token.withLock { $0 = nil } }
}
