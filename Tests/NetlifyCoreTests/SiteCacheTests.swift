import Foundation
import NetlifyCore
import NetlifyTesting
import Testing

@Suite("The site cache")
struct SiteCacheTests {
    let test = TestContext()
    var cache: SiteCache { SiteCache(paths: test.paths) }

    @Test func roundTrips() throws {
        try cache.write([Fixtures.site()], savedAt: Fixtures.now)
        #expect(cache.read() == CachedSites(sites: [Fixtures.site()], savedAt: Fixtures.now))
        #expect(cache.site(id: "s1")?.name == "dulcet-paletas-403ab7")
        #expect(cache.site(id: "nope") == nil)
    }

    @Test func anotherVersionReadsAsNoCache() throws {
        try FileManager.default.createDirectory(at: test.paths.accountFolder, withIntermediateDirectories: true)
        try Data(#"{"version":0,"savedAt":"2026-11-20T12:00:00Z","sites":[]}"#.utf8).write(to: test.paths.sitesFile)
        #expect(cache.read() == nil)
    }

    @Test func problemsAreRecordedAndCleared() throws {
        try cache.write(problem: .failed(message: "offline"))
        #expect(cache.readProblem() == .failed(message: "offline"))
        try cache.write(problem: nil)
        #expect(cache.readProblem() == nil)
    }

    @Test func forgettingTheAccountDeletesItsFolderButNotADemo() throws {
        try cache.write([Fixtures.site()], savedAt: Fixtures.now)
        try test.paths.forgetAccount()
        #expect(cache.read() == nil)

        let demo = TestContext(demo: true)
        try demo.cache([Fixtures.site()])
        try demo.paths.forgetAccount()
        #expect(SiteCache(paths: demo.paths).read() != nil)
    }
}
