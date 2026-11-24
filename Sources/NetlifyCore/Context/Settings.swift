import Foundation

/// What the workflow's environment variables set. Read once, at start.
public struct Settings: Equatable, Sendable {
    /// The workflow's bundle id (`alfred_workflow_bundleid`); names the default cache folder and the reopen trigger.
    public var bundleID: String
    /// How old the cache may get before the window starts a refresh (`cache_minutes`, default 5).
    public var refreshAfter: TimeInterval
    /// Demo mode (`netlify_demo`): this folder of made-up sites stands in for the account. Nothing is fetched.
    public var demoFolder: URL?
    /// The public client id of the "Alfred Netlify" OAuth app. Fixed; tests may inject another.
    public var clientID: String

    public static let defaultBundleID = "work.mattias.alfred.netlify"
    public static let defaultClientID = "Wxby0mMmqordEtMNcxd_0lL5bWEtam5Yi0LwPuFTk2Y"
    /// The refresh age used when `cache_minutes` is empty or not a positive number.
    public static let defaultRefreshMinutes: Double = 5

    public init(
        bundleID: String = Settings.defaultBundleID,
        refreshAfter: TimeInterval = Settings.defaultRefreshMinutes * 60,
        demoFolder: URL? = nil,
        clientID: String = Settings.defaultClientID
    ) {
        self.bundleID = bundleID
        self.refreshAfter = refreshAfter
        self.demoFolder = demoFolder
        self.clientID = clientID
    }

    /// Settings from Alfred's environment variables. Values are trimmed; empty ones count as unset.
    public init(environment: [String: String]) {
        func value(_ name: String) -> String? {
            environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        }
        self.init(
            bundleID: value("alfred_workflow_bundleid") ?? Settings.defaultBundleID,
            refreshAfter: Settings.refreshMinutes(value("cache_minutes")) * 60,
            demoFolder: value("netlify_demo").map { URL(filePath: $0, directoryHint: .isDirectory) }
        )
    }

    public var isDemo: Bool { demoFolder != nil }

    /// The "Refresh after (minutes)" setting: a positive, finite number, else the default of 5.
    static func refreshMinutes(_ text: String?) -> Double {
        guard let minutes = text.flatMap(Double.init), minutes.isFinite, minutes > 0 else {
            return defaultRefreshMinutes
        }
        return minutes
    }
}
