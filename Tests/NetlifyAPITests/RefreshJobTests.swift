import Foundation
import NetlifyAPI
import NetlifyCore
import NetlifyTesting
import Testing

@Suite("Refresh")
struct RefreshJobTests {
    @Test func cachesEverySiteLastPublishedFirst() async throws {
        let sites = NetlifyJSON.body([
            NetlifyJSON.site(id: "old", published: NetlifyJSON.deploy(id: "d-old", createdAt: "2025-03-01T10:00:00Z")),
            NetlifyJSON.site(id: "never-old", createdAt: "2025-01-01T10:00:00Z"),
            NetlifyJSON.site(id: "new", published: NetlifyJSON.deploy(id: "d-new", createdAt: "2026-11-19T10:00:00Z")),
            NetlifyJSON.site(id: "never-new", createdAt: "2026-06-01T10:00:00Z"),
        ])
        let test = TestContext(http: Self.account(sites: sites))

        await refresher(test).refresh()

        let cached = try #require(SiteCache(paths: test.paths).read())
        #expect(cached.sites.map(\.id) == ["new", "old", "never-new", "never-old"])
        #expect(cached.savedAt == Fixtures.now)
        #expect(SiteCache(paths: test.paths).readProblem() == nil)
    }

    @Test func looksUpTheNewestDeployOfThe12MostRecentlyUpdatedSites() async throws {
        let sites = NetlifyJSON.body((1...14).map { day in
            NetlifyJSON.site(id: "s\(day)", updatedAt: String(format: "2026-11-%02dT10:00:00Z", day), published: NetlifyJSON.deploy(id: "live\(day)"))
        })
        let building = NetlifyJSON.body([NetlifyJSON.deploy(id: "new", state: "building")])
        let test = TestContext(http: Self.account(sites: sites) { request in
            request.endpoint.hasSuffix("/deploys") ? HTTPResponse(status: 200, body: building) : nil
        })

        await refresher(test).refresh()

        let cached = try #require(SiteCache(paths: test.paths).read()).sites
        let lookedUp = Set(test.http.requests.filter { $0.endpoint.hasSuffix("/deploys") }.map { $0.url.pathComponents[4] })
        #expect(lookedUp == Set((3...14).map { "s\($0)" }))
        #expect(cached.first { $0.id == "s14" }?.newestDeploy?.phase == .building)
        #expect(cached.first { $0.id == "s2" }?.newestDeploy == nil)
    }

    @Test func countsFormsOnlyForSitesThatUseThem() async throws {
        let sites = NetlifyJSON.body([NetlifyJSON.site(id: "forms", usesForms: true), NetlifyJSON.site(id: "plain")])
        let test = TestContext(http: Self.account(sites: sites) { request in
            request.endpoint.hasSuffix("/forms") ? .json(#"[{"submission_count": 4}]"#) : nil
        })

        await refresher(test).refresh()

        let cached = try #require(SiteCache(paths: test.paths).read()).sites
        #expect(test.http.requests.filter { $0.endpoint.hasSuffix("/forms") }.map(\.endpoint) == ["GET /api/v1/sites/forms/forms"])
        #expect(cached.first { $0.id == "forms" }?.forms == Site.Forms(count: 1, submissions: 4))
        #expect(cached.first { $0.id == "plain" }?.forms == nil)
    }

    @Test func aFailedLookupDoesntFailTheRefresh() async throws {
        let sites = NetlifyJSON.body([NetlifyJSON.site(id: "a", usesForms: true), NetlifyJSON.site(id: "b")])
        let test = TestContext(http: Self.account(sites: sites) { request in
            if request.url.path().contains("/sites/a/") { throw URLError(.timedOut) }
            return request.endpoint.hasSuffix("/deploys") ? .json(#"[{"id": "db", "state": "error", "context": "production", "created_at": "2026-11-20T11:00:00Z"}]"#) : nil
        })

        await refresher(test).refresh()

        let cached = try #require(SiteCache(paths: test.paths).read()).sites
        #expect(cached.map(\.id).sorted() == ["a", "b"])
        #expect(cached.first { $0.id == "a" }?.forms == nil)
        #expect(cached.first { $0.id == "b" }?.newestDeploy?.phase == .failed)
        #expect(SiteCache(paths: test.paths).readProblem() == nil)
    }

    @Test func aRejectedTokenIsRecordedAndTheOldListKept() async throws {
        let test = TestContext(http: FakeHTTP { _ in HTTPResponse(status: 401) })
        try test.cache([Fixtures.site()], age: 600)

        await refresher(test).refresh()

        #expect(SiteCache(paths: test.paths).readProblem() == .signInRejected)
        #expect(SiteCache(paths: test.paths).read()?.sites == [Fixtures.site()])
    }

    @Test func beingOfflineIsRecordedAndTheOldListKept() async throws {
        let test = TestContext(http: FakeHTTP { _ in throw URLError(.notConnectedToInternet) })
        try test.cache([Fixtures.site()], age: 600)

        await refresher(test).refresh()

        let problem = SiteCache(paths: test.paths).readProblem()
        #expect(problem == .failed(message: URLError(.notConnectedToInternet).localizedDescription))
        #expect(SiteCache(paths: test.paths).read()?.savedAt == Fixtures.now - 600)
    }

    @Test func netlifysMessageIsRecorded() async throws {
        let test = TestContext(http: FakeHTTP { _ in .json(#"{"message": "Service unavailable"}"#, status: 503) })

        await refresher(test).refresh()

        #expect(SiteCache(paths: test.paths).readProblem() == .failed(message: "Netlify answered 503: Service unavailable"))
        #expect(SiteCache(paths: test.paths).read() == nil)
    }

    @Test func aGoodRefreshClearsTheLastProblem() async throws {
        let test = TestContext(http: Self.account(sites: NetlifyJSON.body([NetlifyJSON.site(id: "a")])))
        try SiteCache(paths: test.paths).write(problem: .failed(message: "offline"))

        await refresher(test).refresh()

        #expect(SiteCache(paths: test.paths).readProblem() == nil)
        #expect(SiteCache(paths: test.paths).read()?.sites.map(\.id) == ["a"])
    }

    @Test func onlyOneRefreshRunsAtATime() async throws {
        let test = TestContext(http: Self.account(sites: NetlifyJSON.body([NetlifyJSON.site(id: "a")])))

        await JobLock(.refresh, paths: test.paths).tryHolding {
            await refresher(test).refresh()
        }

        #expect(test.http.requests.isEmpty)
        #expect(SiteCache(paths: test.paths).read() == nil)
    }

    @Test func signedOutDoesNothing() async {
        let test = TestContext(token: nil)

        await refresher(test).refresh()

        #expect(test.http.requests.isEmpty)
        #expect(SiteCache(paths: test.paths).readProblem() == nil)
    }

    @Test func demoModeNeverFetches() async {
        let test = TestContext(demo: true)

        await refresher(test).refresh()

        #expect(test.http.requests.isEmpty)
        #expect(SiteCache(paths: test.paths).read() == nil)
    }

    @Test func resetDuringFetchDiscardsTheOldAccountAndItsErrors() async throws {
        for fails in [false, true] {
            let test = TestContext()
            var context = test.context
            context.http = FakeHTTP { _ in
                try test.paths.forgetAccount()
                if fails { throw URLError(.notConnectedToInternet) }
                return .json("[]")
            }
            await RefreshJob(context: context, client: NetlifyClient(context: context)).refresh()
            #expect(!FileManager.default.fileExists(atPath: test.paths.accountFolder.path))
        }
    }

    @Test func aNewAccountRefreshDoesNotWaitForTheOldAccount() async throws {
        let test = TestContext(http: Self.account(sites: NetlifyJSON.body([NetlifyJSON.site(id: "new")])) )
        try await JobLock(.refresh, paths: test.paths).tryHolding {
            try test.paths.forgetAccount()
            await refresher(test).refresh()
        }
        #expect(SiteCache(paths: test.paths).read()?.sites.map(\.id) == ["new"])
    }

    private func refresher(_ test: TestContext) -> RefreshJob {
        RefreshJob(context: test.context, client: NetlifyClient(context: test.context))
    }

    /// An account whose `GET /sites` answers `sites`; other requests go to `lookups`, else get `[]`.
    private static func account(
        sites: Data,
        lookups: @escaping @Sendable (HTTPRequest) throws -> HTTPResponse? = { _ in nil }
    ) -> FakeHTTP {
        FakeHTTP { request in
            if request.endpoint == "GET /api/v1/sites" {
                return HTTPResponse(status: 200, body: sites)
            }
            return try lookups(request) ?? .json("[]")
        }
    }
}
