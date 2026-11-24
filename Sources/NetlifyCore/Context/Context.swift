import Foundation

/// Everything outside the code that a part may touch: settings, folders, network, Keychain, background jobs, the
/// Mac, and time. Every part takes one in `init`; NetlifyCLI builds the live one, tests build `TestContext`.
public struct Context: Sendable {
    public var settings: Settings
    public var paths: Paths
    public var http: any HTTPClient
    public var tokens: any TokenStore
    public var jobs: any JobLauncher
    public var system: any SystemActions
    /// The current time.
    public var now: @Sendable () -> Date
    /// Waits; tests pass one that returns at once.
    public var sleep: @Sendable (Duration) async throws -> Void

    public init(
        settings: Settings,
        paths: Paths,
        http: any HTTPClient,
        tokens: any TokenStore,
        jobs: any JobLauncher,
        system: any SystemActions,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.settings = settings
        self.paths = paths
        self.http = http
        self.tokens = tokens
        self.jobs = jobs
        self.system = system
        self.now = now
        self.sleep = sleep
    }

    /// Demo mode counts as signed in; a Keychain error counts as signed out.
    public var isSignedIn: Bool {
        settings.isDemo || (try? tokens.read()) != nil
    }
}
