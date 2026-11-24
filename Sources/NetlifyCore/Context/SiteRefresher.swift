/// Fetches every site of the account into `SiteCache`. NetlifyAPI's `RefreshJob` is the real one; ⌘R in the window
/// and the sign-in job call it.
public protocol SiteRefresher: Sendable {
    /// Fetch and write the cache, or record a `RefreshProblem`. Never throws: problems end up in the cache folder,
    /// where the window reads them. Holds the `refresh` job lock while it runs.
    func refresh() async
}
