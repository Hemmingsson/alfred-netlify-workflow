import Foundation
import NetlifyCore
import NetlifyTesting
import Testing
@testable import NetlifyWindow

@Suite("List rows and the detail pane")
struct SitePresenterTests {
    let test = TestContext()

    func presenter(_ pictures: FakePictures = FakePictures(), demo: Bool = false) -> SitePresenter {
        let paths = demo ? TestContext(demo: true).paths : test.paths
        return SitePresenter(text: TextFormatter(now: Fixtures.now, timeZone: TimeZone(identifier: "UTC")!), pictures: pictures, paths: paths)
    }

    func row(_ site: Site, _ pictures: FakePictures = FakePictures()) throws -> [String: Any] {
        let data = try JSONEncoder().encode(presenter(pictures).row(for: site))
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    func detail(_ site: Site) -> [String: ComponentChange] { presenter().detail(for: site) }

    func failing(_ state: String, error: String? = nil) -> Site {
        var site = Fixtures.site()
        var latest = Fixtures.deploy(id: "d2", state: state, createdAt: "2026-11-20T09:00:00Z")
        latest.errorMessage = error
        latest.committer = "Someone Else"
        latest.commitRef = "abcdef1234"
        site.newestDeploy = latest
        return site
    }

    @Test func aPublishedSiteRow() throws {
        let row = try row(Fixtures.site())
        #expect(row["uid"] as? String == "s1")
        #expect(row["rowTitle.text"] as? String == "streamdeck-canvas.example")
        #expect(row["rowSubtitle.text"] as? String == "einride-ro-streamdeck")
        #expect(row["rowAge.text"] as? String == "1 d ago")
        #expect(row["rowState.text"] as? String == "")
        #expect((row["rowRepositoryIcon.image"] as? [String: String])?["src"] == test.paths.githubIcon.path)
        #expect((row["rowThumbnail.image"] as? [String: String])?["src"] == test.paths.workflowIcon.path)
        #expect(row["openSite"] as? String == "open:https://streamdeck-canvas.example")
        #expect(row["openProject"] as? String == "open:https://app.netlify.com/projects/dulcet-paletas-403ab7")
        #expect(row["openDeploys"] as? String == "open:https://app.netlify.com/projects/dulcet-paletas-403ab7/deploys")
        #expect(row["copyURL"] as? String == "copy:https://streamdeck-canvas.example")
    }

    @Test func titleFallsBackToTheURLHostThenTheNetlifyDomain() {
        var site = Fixtures.site()
        site.customDomain = nil
        site.url = URL(string: "https://xn--spo-qla.com")
        #expect(SiteSummary(site).host == "säpo.com")
        site.url = nil
        #expect(SiteSummary(site).host == "dulcet-paletas-403ab7.netlify.app")
    }

    @Test func withoutARepositoryTheSubtitleIsTheProjectNameAndTheIconABox() throws {
        var site = Fixtures.site()
        site.repository = nil
        let row = try row(site)
        #expect(row["rowSubtitle.text"] as? String == "dulcet-paletas-403ab7")
        #expect((row["rowRepositoryIcon.image"] as? [String: String])?["src"] == "shippingbox")
        site.repository = Repository(url: URL(string: "https://gitlab.com/a/b.git")!, provider: "gitlab")
        #expect((try self.row(site)["rowRepositoryIcon.image"] as? [String: String])?["src"] == "arrow.triangle.branch")
        #expect(try self.row(site)["rowSubtitle.text"] as? String == "b")
    }

    @Test func theThumbnailComesFromThePictures() throws {
        let thumb = URL(filePath: "/tmp/thumb 1.png")
        #expect((try row(Fixtures.site(), FakePictures(thumbnails: ["s1": thumb]))["rowThumbnail.image"] as? [String: String])?["src"] == thumb.path)
    }

    @Test func statesShowOnlyExceptions() {
        #expect(SiteState(Fixtures.site()).label == nil)
        var locked = Fixtures.site()
        locked.publishedDeploy?.isLocked = true
        #expect(SiteState(locked) == .locked)
        #expect(SiteState(locked).colour == .yellow)
        var never = Fixtures.site()
        never.publishedDeploy = nil
        #expect(SiteState(never).label == "Not published")
        #expect(SiteState(failing("error")).label == "Failed")
        #expect(SiteState(failing("error")).colour == .red)
        #expect(SiteState(failing("building")).label == "Building")
        #expect(SiteState(failing("building")).colour == .orange)
    }

    @Test func failedAndBuildingWinOverLockedButNotWhenTheyAreLive() {
        var site = failing("error")
        site.publishedDeploy?.isLocked = true
        #expect(SiteState(site).label == "Failed")
        site.newestDeploy = site.publishedDeploy
        #expect(SiteState(site) == .locked)
    }

    @Test func searchCoversNamesAndTheirPiecesWithoutNoise() {
        var site = Fixtures.site()
        site.customDomain = "bland.band"
        site.domainAliases = ["www.xn--spo-qla.com"]
        let words = Set(SiteSummary(site).searchText.split(separator: " ").map(String.init))
        #expect(words.isSuperset(of: ["bland.band", "band", "bland", "dulcet-paletas-403ab7", "paletas", "dulcet",
                                      "einride-ro-streamdeck", "streamdeck", "säpo"]))
        #expect(words.isDisjoint(with: ["netlify", "app", "www", "com"]))
    }

    @Test func projectNameShowsTheNetlifyNameOnlyWhenTheRowShowsTheRepository() {
        #expect(detail(Fixtures.site())["projectName"]?.text == "dulcet-paletas-403ab7")
        var site = Fixtures.site()
        site.repository = nil
        site.publishedDeploy?.source = "cli"
        #expect(detail(site)["projectName"]?.text == "Deployed with the Netlify CLI")
        site.publishedDeploy?.source = "api"
        #expect(detail(site)["projectName"]?.text == "Deployed through the API")
        site.publishedDeploy?.source = nil
        #expect(detail(site)["projectName"]?.text == "Deployed by drag and drop")
        site.publishedDeploy = nil
        #expect(detail(site)["projectName"]?.text == "Nothing deployed")
    }

    @Test func stackText() {
        var site = Fixtures.site()
        #expect(presenter().stackText(site) == "SvelteKit · 1 function")
        site.publishedDeploy?.functionCount = 3
        site.publishedDeploy?.scheduledFunctionCount = 1
        site.publishedDeploy?.hasEdgeFunctions = true
        site.forms = .init(count: 2, submissions: 1)
        #expect(presenter().stackText(site) == "SvelteKit · 3 functions, 1 scheduled · edge functions · 2 forms, 1 submission")
        site.forms = nil
        site.usesForms = true
        site.publishedDeploy?.framework = "unknown"
        site.publishedDeploy?.functionCount = 0
        site.publishedDeploy?.hasEdgeFunctions = false
        #expect(presenter().stackText(site) == "forms")
        site.forms = .init(count: 0, submissions: 0)
        #expect(presenter().stackText(site) == "Static site")
        site.usesForms = false
        #expect(presenter().stackText(site) == "Static site")
    }

    @Test func domainsRowListsOtherDomainsAndWarnings() {
        var site = Fixtures.site()
        #expect(detail(site)["projectDomains"]?.text == "dulcet-paletas-403ab7.netlify.app")
        site.domainAliases = ["xn--spo-qla.com", "b.example"]
        site.hasPassword = true
        #expect(detail(site)["projectDomains"]?.text == "dulcet-paletas-403ab7.netlify.app +2 · Password protected")
        site.customDomain = nil
        site.domainAliases = []
        site.hasPassword = false
        #expect(detail(site)["projectDomains"]?.text == "")
        #expect(detail(site)["projectDomainsRow"]?.hidden == true)
        site.url = URL(string: "http://plain.example")
        site.hasSSL = false
        #expect(detail(site)["projectDomains"]?.text == "HTTP only")
    }

    @Test func latestDeployForAPublishedSite() {
        let detail = detail(Fixtures.site())
        #expect(detail["deployMessage"]?.text == "Merge remote-tracking branch 'origin/canvas-perf'")
        #expect(detail["deployMessage"]?.tooltip == "Merge remote-tracking branch 'origin/canvas-perf'\n\nmore")
        #expect(detail["deployMessage"]?.colour == .label)
        #expect(detail["deployMessageIcon"]?.image == .symbol("text.bubble"))
        #expect(detail["deployWho"]?.text == "Hemmingsson · Nov 18 at 16:00")
        #expect(detail["deployRef"]?.text == "main · 0d59114")
        #expect(detail["deployRefRow"]?.hidden == false)
    }

    @Test func deploysWithoutACommitSayHowTheyWereDeployed() {
        var site = Fixtures.site()
        site.publishedDeploy?.title = nil
        site.publishedDeploy?.source = "cli"
        #expect(detail(site)["deployMessage"]?.text == "Deployed with the Netlify CLI")
        site.publishedDeploy?.source = nil
        #expect(detail(site)["deployMessage"]?.text == "Manual deploy")
        site.repository = nil
        #expect(detail(site)["deployRefRow"]?.hidden == true)
    }

    @Test func aFailedNewestDeployDescribesThatDeployInEveryRow() {
        let detail = detail(failing("error", error: "Build script returned non-zero exit code: 2\nmore"))
        #expect(detail["deployMessage"]?.text == "Failed 3 h ago: Build script returned non-zero exit code: 2")
        #expect(detail["deployMessage"]?.colour == .red)
        #expect(detail["deployMessageIcon"]?.image == .symbol("xmark.octagon"))
        #expect(detail["deployMessageIcon"]?.tint == .red)
        #expect(detail["deployWho"]?.text == "Someone Else · Nov 20 at 09:00")
        #expect(detail["deployRef"]?.text == "main · abcdef1")
    }

    @Test func buildingAndLockedMessages() {
        let building = detail(failing("building"))
        #expect(building["deployMessage"]?.text == "Building, started 3 h ago")
        #expect(building["deployMessageIcon"]?.image == .symbol("hammer"))
        var site = Fixtures.site()
        site.publishedDeploy?.isLocked = true
        #expect(detail(site)["deployMessage"]?.text == "Locked: auto publishing stopped")
        #expect(detail(site)["deployMessageIcon"]?.image == .symbol("lock"))
    }

    @Test func neverPublishedHasNoPictureNoWhoAndNoRef() {
        var site = Fixtures.site()
        site.publishedDeploy = nil
        let detail = detail(site)
        #expect(detail["deployMessage"]?.text == "Not published yet")
        #expect(detail["deployMessage"]?.colour == .secondaryLabel)
        #expect(detail["deployWhoRow"]?.hidden == true)
        #expect(detail["deployRefRow"]?.hidden == true)
        #expect(detail["pictureView"]?.image == .empty)
        #expect(presenter(FakePictures(framing: ["s1": true])).livePreview(for: site) == .hidden)
    }

    @Test func pictureAndFaviconFallBack() {
        #expect(detail(Fixtures.site())["pictureView"]?.image == .file(test.paths.workflowIcon))
        #expect(detail(Fixtures.site())["addressIcon"]?.image == .symbol("globe"))
        let favicon = URL(filePath: "/tmp/f.png")
        #expect(presenter(FakePictures(favicons: ["s1": favicon])).detail(for: Fixtures.site())["addressIcon"]?.image == .file(favicon))
    }

    @Test func theLivePreviewWaitsUntilFramingIsKnownToBeAllowed() throws {
        #expect(presenter().livePreview(for: Fixtures.site()) == .hidden)
        #expect(presenter(FakePictures(framing: ["s1": false])).livePreview(for: Fixtures.site()) == .hidden)
        let picture = URL(filePath: "/tmp/pic 1.png")
        let preview = presenter(FakePictures(pictures: ["s1": picture], framing: ["s1": true])).livePreview(for: Fixtures.site())
        #expect(!preview.isHidden)
        let html = try String(contentsOfFile: preview.source, encoding: .utf8)
        #expect(html.contains(#"<iframe id=f src="https://streamdeck-canvas.example">"#))
        #expect(html.contains(picture.absoluteString))
        #expect(!html.contains("scrolling=no"))
        #expect(preview.component == .webView(id: "livePreview", src: SafeText(preview.source), opacity: 1))
    }

    @Test func demoModeShowsThePictureOnly() {
        #expect(presenter(FakePictures(framing: ["s1": true]), demo: true).livePreview(for: Fixtures.site()) == .hidden)
    }

    @Test func previewPagesEscapeTheURL() {
        let html = PreviewPages.html(url: URL(string: "https://a.example/?q=\"><script>")!, picture: nil)
        #expect(!html.contains("\"><script>"))
    }
}
