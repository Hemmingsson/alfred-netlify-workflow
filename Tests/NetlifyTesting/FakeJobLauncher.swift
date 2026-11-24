import NetlifyCore

/// A JobLauncher that only records what it was asked to start.
public final class FakeJobLauncher: JobLauncher {
    private let log = Locked<[BackgroundJob]>([])

    public init() {}

    public var launched: [BackgroundJob] { log.value }

    public func launch(_ job: BackgroundJob) {
        log.withLock { $0.append(job) }
    }
}
