import Foundation
import NetlifyAPI
@testable import NetlifyCLI
import NetlifyCore
import NetlifyTesting
import Testing

/// Talks to the real Netlify API with the token in the Keychain; read-only. Run by hand, signed in:
/// `NETLIFY_LIVE_CHECK=1 swift test --filter LiveAccountCheck`. Never part of a normal `swift test`.
@Suite("Live Netlify account", .enabled(if: ProcessInfo.processInfo.environment["NETLIFY_LIVE_CHECK"] == "1"))
struct LiveAccountCheck {
    @Test func refreshesTheRealAccount() async throws {
        let test = TestContext()
        var context = test.context
        context.http = URLSessionHTTPClient()
        context.tokens = KeychainTokenStore()
        let client = NetlifyClient(context: context)

        await RefreshJob(context: context, client: client).refresh()

        #expect(SiteCache(paths: test.paths).readProblem() == nil)
        let sites = try #require(SiteCache(paths: test.paths).read()).sites
        print("Live check: \(sites.count) sites, \(sites.filter { $0.newestDeploy != nil }.count) with their newest deploy")
        for site in sites.prefix(5) {
            print("  \(site.customDomain ?? site.netlifyDomain) · \(site.repository?.name ?? "no repo") · \(site.publishedDeploy?.state ?? "never published")")
        }
    }
}
