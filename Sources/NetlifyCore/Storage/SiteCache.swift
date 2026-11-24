import Foundation

/// The account's sites as the last refresh saw them (`sites.json`), and the last refresh's problem
/// (`refresh-problem.json`). Written by the refresh job, read by everything else.
public struct SiteCache: Sendable {
    /// Bump when `Site` changes shape; an older file reads as no cache, and the window fetches again.
    public static let version = 1

    public let paths: Paths

    public init(paths: Paths) {
        self.paths = paths
    }

    /// The cached sites, or nil when there is no cache of this version.
    public func read() -> CachedSites? {
        guard let file = JSON.read(SitesFile.self, from: paths.sitesFile), file.version == Self.version else { return nil }
        return CachedSites(sites: file.sites, savedAt: file.savedAt)
    }

    /// Replace the cache. Keeps the order given (the refresh sorts).
    public func write(_ sites: [Site], savedAt: Date) throws {
        try JSON.write(SitesFile(version: Self.version, savedAt: savedAt, sites: sites), to: paths.sitesFile)
    }

    /// One cached site.
    public func site(id: String) -> Site? {
        read()?.sites.first { $0.id == id }
    }

    /// The last refresh's problem; nil when it went well.
    public func readProblem() -> RefreshProblem? {
        JSON.read(RefreshProblem.self, from: paths.refreshProblemFile)
    }

    /// Record the last refresh's problem; nil clears it.
    public func write(problem: RefreshProblem?) throws {
        guard let problem else {
            try? FileManager.default.removeItem(at: paths.refreshProblemFile)
            return
        }
        try JSON.write(problem, to: paths.refreshProblemFile)
    }

    private struct SitesFile: Codable {
        var version: Int
        var savedAt: Date
        var sites: [Site]
    }
}

/// The sites in the cache, and when they were fetched.
public struct CachedSites: Equatable, Sendable {
    public var sites: [Site]
    public var savedAt: Date

    public init(sites: [Site], savedAt: Date) {
        self.sites = sites
        self.savedAt = savedAt
    }

    public func age(at now: Date) -> TimeInterval { now.timeIntervalSince(savedAt) }
}
