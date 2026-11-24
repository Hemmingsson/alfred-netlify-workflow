import Foundation
import NetlifyAPI
import NetlifyCore
import NetlifyTesting
import Testing

@Suite("Netlify API client")
struct NetlifyClientTests {
    @Test func fetchesEverySiteAcrossPages() async throws {
        let first = NetlifyJSON.body([NetlifyJSON.site(id: "a"), NetlifyJSON.site(id: "b")])
        let second = NetlifyJSON.body([NetlifyJSON.site(id: "c")])
        let http = FakeHTTP { request in
            if request.query("page") == "2" {
                return HTTPResponse(status: 200, body: second)
            }
            let next = "<https://api.netlify.com/api/v1/sites?filter=all&page=2&per_page=100>; rel=\"next\", "
                + "<https://api.netlify.com/api/v1/sites?filter=all&page=2&per_page=100>; rel=\"last\""
            return HTTPResponse(status: 200, headers: ["Link": next], body: first)
        }
        let test = TestContext(token: "secret", http: http)

        let sites = try await NetlifyClient(context: test.context).sites()

        #expect(sites.map(\.id) == ["a", "b", "c"])
        #expect(http.requests.count == 2)
        let request = try #require(http.requests.first)
        #expect(request.endpoint == "GET /api/v1/sites")
        #expect(request.query("filter") == "all")
        #expect(request.query("per_page") == "100")
        #expect(request.headers["Authorization"] == "Bearer secret")
    }

    @Test func neverSendsTheTokenToAnotherHost() async throws {
        let page = NetlifyJSON.body([NetlifyJSON.site(id: "a")])
        let http = FakeHTTP { _ in
            HTTPResponse(status: 200, headers: ["Link": "<https://example.com/steal?page=2>; rel=\"next\""], body: page)
        }
        let test = TestContext(http: http)

        let sites = try await NetlifyClient(context: test.context).sites()

        #expect(sites.map(\.id) == ["a"])
        #expect(http.requests.count == 1)
    }

    @Test func stopsWhenTheNextPageRepeats() async throws {
        let page = NetlifyJSON.body([NetlifyJSON.site(id: "a")])
        let http = FakeHTTP { request in
            HTTPResponse(status: 200, headers: ["Link": "<\(request.url.absoluteString)>; rel=\"next\""], body: page)
        }
        let test = TestContext(http: http)

        _ = try await NetlifyClient(context: test.context).sites()

        #expect(http.requests.count == 1)
    }

    @Test func readsEverythingTheWindowShowsAboutASite() async throws {
        let http = FakeHTTP { _ in .json(Self.fullSite) }
        let test = TestContext(http: http)

        let site = try #require(try await NetlifyClient(context: test.context).sites().first)

        #expect(site.id == "5a3e")
        #expect(site.name == "dulcet-paletas-403ab7")
        #expect(site.url == URL(string: "https://streamdeck-canvas.example"))
        #expect(site.customDomain == "streamdeck-canvas.example")
        #expect(site.domainAliases == ["www.streamdeck-canvas.example"])
        #expect(site.netlifyDomain == "dulcet-paletas-403ab7.netlify.app")
        #expect(site.adminURL == URL(string: "https://app.netlify.com/projects/dulcet-paletas-403ab7"))
        #expect(site.createdAt == Fixtures.date("2026-11-18T10:00:00.250Z"))
        #expect(site.updatedAt == Fixtures.date("2026-11-18T16:05:00Z"))
        #expect(site.screenshotURL == URL(string: "https://d33wubrfki0l68.cloudfront.net/d1/screenshot.webp"))
        #expect(site.repository == Repository(url: URL(string: "https://github.com/example/einride-ro-streamdeck")!, provider: "github"))
        #expect(site.hasSSL)
        #expect(site.hasPassword)
        #expect(site.usesForms)
        #expect(site.forms == nil)
        #expect(site.newestDeploy == nil)

        let deploy = try #require(site.publishedDeploy)
        #expect(deploy.id == "d1")
        #expect(deploy.state == "ready")
        #expect(deploy.branch == "main")
        #expect(deploy.commitRef == "0d591148aa2f")
        #expect(deploy.committer == "Hemmingsson")
        #expect(deploy.title == "Merge branch 'canvas-perf'\n\nFaster drawing")
        #expect(deploy.source == "github")
        #expect(deploy.createdAt == Fixtures.date("2026-11-18T16:00:00.123Z"))
        #expect(deploy.publishedAt == Fixtures.date("2026-11-18T16:01:30.456Z"))
        #expect(deploy.errorMessage == nil)
        #expect(deploy.framework == "svelte-kit")
        #expect(deploy.functionCount == 2)
        #expect(deploy.scheduledFunctionCount == 1)
        #expect(deploy.hasEdgeFunctions)
        #expect(deploy.isLocked)
    }

    @Test func leavesOutWhatNetlifySendsAsEmpty() async throws {
        let http = FakeHTTP { _ in .json(Self.bareSite) }
        let test = TestContext(http: http)

        let site = try #require(try await NetlifyClient(context: test.context).sites().first)

        #expect(site.url == URL(string: "http://bare.netlify.app"))
        #expect(site.customDomain == nil)
        #expect(site.domainAliases.isEmpty)
        #expect(site.adminURL == nil)
        #expect(site.screenshotURL == nil)
        #expect(site.repository == nil)
        #expect(!site.hasSSL)
        #expect(!site.hasPassword)
        #expect(!site.usesForms)
        #expect(!site.isPublished)
    }

    @Test func aCLIDeployHasNoCommit() async throws {
        let http = FakeHTTP { _ in .json(Self.cliDeploys) }
        let test = TestContext(http: http)

        let deploy = try #require(try await NetlifyClient(context: test.context).newestProductionDeploy(siteID: "s1"))

        #expect(deploy.source == "cli")
        #expect(deploy.title == nil)
        #expect(deploy.branch == nil)
        #expect(deploy.commitRef == nil)
        #expect(deploy.committer == nil)
        #expect(deploy.framework == nil)
        #expect(deploy.errorMessage == "Build script returned non-zero exit code: 2")
        #expect(deploy.phase == .failed)
    }

    @Test(arguments: [
        Operation.sites, .newestDeploy, .forms,
    ])
    func aRejectedTokenMeansSignInAgain(_ operation: Operation) async {
        let test = TestContext(http: FakeHTTP { _ in .json(#"{"code":401,"message":"Access Denied"}"#, status: 401) })

        await #expect(throws: NetlifyError.signInRejected) {
            try await operation.run(NetlifyClient(context: test.context))
        }
    }

    @Test func signedOutSendsNothing() async {
        let test = TestContext(token: nil)

        await #expect(throws: NetlifyError.signedOut) {
            try await NetlifyClient(context: test.context).sites()
        }
        #expect(test.http.requests.isEmpty)
    }

    @Test func otherFailuresCarryNetlifysMessage() async {
        let test = TestContext(http: FakeHTTP { _ in .json(#"{"code":422,"message":"Site is not ready"}"#, status: 422) })

        await #expect(throws: NetlifyError.status(422, message: "Site is not ready")) {
            _ = try await NetlifyClient(context: test.context).forms(siteID: "s1")
        }
    }

    @Test func aFailureWithoutAMessage() async {
        let test = TestContext(http: FakeHTTP { _ in HTTPResponse(status: 502, body: Data("<html>Bad gateway</html>".utf8)) })

        await #expect(throws: NetlifyError.status(502, message: "")) {
            try await NetlifyClient(context: test.context).sites()
        }
    }

    @Test func anAnswerThatIsntASiteList() async {
        let test = TestContext(http: FakeHTTP { _ in .json(#"{"sites": []}"#) })

        await #expect(throws: NetlifyError.unreadableResponse) {
            try await NetlifyClient(context: test.context).sites()
        }
    }

    @Test func newestProductionDeploy() async throws {
        let deploys = NetlifyJSON.body([NetlifyJSON.deploy(id: "d2", state: "building")])
        let http = FakeHTTP { _ in HTTPResponse(status: 200, body: deploys) }
        let test = TestContext(http: http)

        let deploy = try await NetlifyClient(context: test.context).newestProductionDeploy(siteID: "s1")

        #expect(deploy?.id == "d2")
        #expect(deploy?.phase == .building)
        let request = try #require(http.requests.first)
        #expect(request.endpoint == "GET /api/v1/sites/s1/deploys")
        #expect(request.query("production") == "true")
        #expect(request.query("per_page") == "1")
    }

    @Test func aSiteWithoutProductionDeploys() async throws {
        let test = TestContext(http: FakeHTTP { _ in .json("[]") })

        #expect(try await NetlifyClient(context: test.context).newestProductionDeploy(siteID: "s1") == nil)
    }

    @Test func countsFormsAndSubmissions() async throws {
        let http = FakeHTTP { _ in .json(#"[{"name":"contact","submission_count":12},{"name":"signup","submission_count":3},{"name":"new"}]"#) }
        let test = TestContext(http: http)

        let forms = try await NetlifyClient(context: test.context).forms(siteID: "s1")

        #expect(forms == Site.Forms(count: 3, submissions: 15))
        #expect(http.requests.first?.endpoint == "GET /api/v1/sites/s1/forms")
    }

    @Test func idsCantAddPathSegments() async throws {
        let http = FakeHTTP { _ in .json("[]") }
        let test = TestContext(http: http)

        _ = try await NetlifyClient(context: test.context).forms(siteID: "../accounts")

        let url = try #require(http.requests.first?.url)
        #expect(url.absoluteString == "https://api.netlify.com/api/v1/sites/..%2Faccounts/forms")
    }

    /// Each call of the client, for tests that apply to all of them.
    enum Operation: CaseIterable, Sendable {
        case sites, newestDeploy, forms

        func run(_ client: NetlifyClient) async throws {
            switch self {
            case .sites: _ = try await client.sites()
            case .newestDeploy: _ = try await client.newestProductionDeploy(siteID: "s1")
            case .forms: _ = try await client.forms(siteID: "s1")
            }
        }
    }

    /// A site with everything set, trimmed from a real `GET /sites` answer.
    static let fullSite = """
        [{
          "id": "5a3e",
          "name": "dulcet-paletas-403ab7",
          "url": "http://streamdeck-canvas.example",
          "ssl_url": "https://streamdeck-canvas.example",
          "custom_domain": "streamdeck-canvas.example",
          "domain_aliases": ["www.streamdeck-canvas.example"],
          "default_domain": "dulcet-paletas-403ab7.netlify.app",
          "admin_url": "https://app.netlify.com/projects/dulcet-paletas-403ab7",
          "created_at": "2026-11-18T10:00:00.250Z",
          "updated_at": "2026-11-18T16:05:00Z",
          "screenshot_url": "https://d33wubrfki0l68.cloudfront.net/d1/screenshot.webp",
          "ssl": true,
          "has_password": true,
          "use_forms": true,
          "build_settings": {"provider": "github", "repo_url": "https://github.com/example/einride-ro-streamdeck", "repo_branch": "main"},
          "unknown_field": {"anything": [1, 2]},
          "published_deploy": {
            "id": "d1",
            "state": "ready",
            "context": "production",
            "branch": "main",
            "commit_ref": "0d591148aa2f",
            "committer": "Hemmingsson",
            "title": "Merge branch 'canvas-perf'\\n\\nFaster drawing",
            "deploy_source": "github",
            "created_at": "2026-11-18T16:00:00.123Z",
            "published_at": "2026-11-18T16:01:30.456Z",
            "error_message": null,
            "links": {"permalink": "https://d1--dulcet-paletas-403ab7.netlify.app", "alias": "https://dulcet-paletas-403ab7.netlify.app"},
            "deploy_ssl_url": "https://d1--dulcet-paletas-403ab7.netlify.app",
            "framework": "svelte-kit",
            "available_functions": [{"n": "render", "t": "js"}, {"n": "daily", "t": "js"}],
            "function_schedules": [{"name": "daily", "cron": "@daily"}],
            "edge_functions_present": true,
            "locked": true
          }
        }]
        """

    /// A site with no domain, repo, certificate or deploy; Netlify sends empty strings and nulls.
    static let bareSite = """
        [{
          "id": "b1",
          "name": "bare",
          "url": "http://bare.netlify.app",
          "ssl_url": "",
          "custom_domain": null,
          "domain_aliases": [],
          "default_domain": "bare.netlify.app",
          "admin_url": "",
          "created_at": "2026-11-18T10:00:00Z",
          "updated_at": "2026-11-18T10:00:00Z",
          "screenshot_url": null,
          "ssl": false,
          "build_settings": {"repo_url": "", "repo_branch": ""},
          "published_deploy": null
        }]
        """

    /// A failed deploy made with the Netlify CLI.
    static let cliDeploys = """
        [{
          "id": "d9",
          "state": "error",
          "context": "production",
          "branch": "",
          "commit_ref": null,
          "committer": null,
          "title": null,
          "deploy_source": "cli",
          "created_at": "2026-11-19T08:00:00.000Z",
          "published_at": null,
          "error_message": "Build script returned non-zero exit code: 2",
          "links": {"permalink": null},
          "deploy_ssl_url": "https://d9--bare.netlify.app",
          "framework": ""
        }]
        """
}
