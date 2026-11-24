import NetlifyCore

/// A SiteRefresher that counts refreshes and runs `onRefresh` (e.g. to write a cache).
public final class FakeRefresher: SiteRefresher {
    private let onRefresh: @Sendable () -> Void
    private let count = Locked(0)

    public init(onRefresh: @escaping @Sendable () -> Void = {}) {
        self.onRefresh = onRefresh
    }

    public var refreshes: Int { count.value }

    public func refresh() async {
        count.withLock { $0 += 1 }
        onRefresh()
    }
}
