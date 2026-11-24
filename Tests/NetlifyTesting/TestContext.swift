import Foundation
import NetlifyCore

/// A Context for tests: fakes for everything, a fresh temporary cache folder (with a space in its name, like
/// Alfred's "Workflow Data"), and a clock that only moves when told.
public struct TestContext: Sendable {
    public let http: FakeHTTP
    public let tokens: FakeTokenStore
    public let jobs: FakeJobLauncher
    public let system: FakeSystemActions
    public let clock: Locked<Date>
    public let folder: URL
    public let context: Context

    /// Signed in with `token` (nil: signed out). `demo` makes a demo folder stand in for the account.
    public init(token: String? = "token", demo: Bool = false, settings: Settings = Settings(), http: FakeHTTP = FakeHTTP()) {
        let folder = FileManager.default.temporaryDirectory.appending(path: "netlify test \(UUID().uuidString)", directoryHint: .isDirectory)
        let workflow = folder.appending(path: "workflow", directoryHint: .isDirectory)
        let demoFolder = demo ? folder.appending(path: "demo", directoryHint: .isDirectory) : nil
        try? FileManager.default.createDirectory(at: workflow, withIntermediateDirectories: true)
        var settings = settings
        settings.demoFolder = demoFolder
        let clock = Locked(Fixtures.now)
        self.http = http
        self.tokens = FakeTokenStore(token: token)
        self.jobs = FakeJobLauncher()
        self.system = FakeSystemActions()
        self.clock = clock
        self.folder = folder
        self.context = Context(
            settings: settings,
            paths: Paths(cacheFolder: folder.appending(path: "cache", directoryHint: .isDirectory), workflowFolder: workflow, demoFolder: demoFolder),
            http: http,
            tokens: tokens,
            jobs: jobs,
            system: system,
            now: { clock.value },
            sleep: { _ in }
        )
    }

    public var paths: Paths { context.paths }

    /// Move the clock on.
    public func advance(by seconds: TimeInterval) {
        clock.withLock { $0 += seconds }
    }

    /// Write `sites` to the cache, saved `age` seconds ago.
    public func cache(_ sites: [Site], age: TimeInterval = 0) throws {
        try SiteCache(paths: paths).write(sites, savedAt: clock.value - age)
    }
}
