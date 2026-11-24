import Foundation
import NetlifyCore

/// The `refresh` job: fetch every site into `SiteCache`.
///
/// Holding the `refresh` lock, it fetches all sites, then the newest production deploy of the 12 most recently
/// updated ones (so their rows can say Building or Failed) and the form counts of the sites that use forms, at most
/// 6 requests at a time. A lookup that fails leaves its site as it was. The cache is sorted last published first;
/// sites never published come last, newest created first. Success replaces the cache and clears the
/// `RefreshProblem`; failure records it and keeps the old cache. Signed out or in demo mode, it does nothing.
public struct RefreshJob: SiteRefresher {
    /// How many of the most recently updated sites get their newest production deploy looked up.
    static let newestDeployLookups = 12
    /// At most this many lookups at a time.
    static let concurrentLookups = 6

    let context: Context
    let client: NetlifyClient

    public init(context: Context, client: NetlifyClient) {
        self.context = context
        self.client = client
    }

    public func refresh() async {
        guard !context.settings.isDemo, let session = try? AccountSession(paths: context.paths) else { return }
        await JobLock(.refresh, paths: context.paths, session: session).tryHolding {
            await fetchIntoCache(session: session)
        }
    }

    private func fetchIntoCache(session: AccountSession) async {
        let cache = SiteCache(paths: context.paths)
        do {
            let sites = try await completed(client.sites())
            try session.commit {
                try cache.write(Self.listOrder(sites), savedAt: context.now())
                try cache.write(problem: nil)
            }
        } catch NetlifyError.signedOut {
            return
        } catch {
            let problem: RefreshProblem = switch error {
            case NetlifyError.signInRejected: .signInRejected
            default: .failed(message: error.localizedDescription)
            }
            do {
                try session.commit { try cache.write(problem: problem) }
            } catch {
                Log.write("couldn't record the refresh problem: \(error.localizedDescription)")
            }
        }
    }

    /// `sites` with what the lookups found, `concurrentLookups` at a time. A failed lookup changes nothing.
    private func completed(_ sites: [Site]) async -> [Site] {
        let recent = sites.sorted { $0.updatedAt > $1.updatedAt }.prefix(Self.newestDeployLookups)
        let lookups = recent.map { SiteLookup.newestDeploy(siteID: $0.id) }
            + sites.filter(\.usesForms).map { SiteLookup.forms(siteID: $0.id) }
        let findings = await lookups.concurrentMap(limit: Self.concurrentLookups) { [client] lookup in
            (try? await lookup.run(with: client)).map { (siteID: lookup.siteID, apply: $0) }
        }
        var updates: [String: [SiteLookup.Update]] = [:]
        for case let finding? in findings {
            updates[finding.siteID, default: []].append(finding.apply)
        }
        return sites.map { site in
            updates[site.id, default: []].reduce(into: site) { site, apply in apply(&site) }
        }
    }

    /// Last published first; sites never published last, newest created first.
    static func listOrder(_ sites: [Site]) -> [Site] {
        func publishedAt(_ site: Site) -> Date {
            site.publishedDeploy.map { $0.publishedAt ?? $0.createdAt } ?? .distantPast
        }
        let published = sites.filter(\.isPublished).sorted { publishedAt($0) > publishedAt($1) }
        let neverPublished = sites.filter { !$0.isPublished }.sorted { $0.createdAt > $1.createdAt }
        return published + neverPublished
    }
}
