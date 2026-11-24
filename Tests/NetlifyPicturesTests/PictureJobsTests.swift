import Foundation
import NetlifyCore
@testable import NetlifyPictures
import NetlifyTesting
import Testing

/// A site whose screenshot, home page and icon answer like the real thing.
private func workingSite(frameOptions: String? = nil, iconStatus: Int = 200) -> FakeHTTP {
    FakeHTTP { request in
        switch request.url.absoluteString {
        case "https://d33wubrfki0l68.cloudfront.net/screenshot.png":
            HTTPResponse(status: 200, body: TestImages.png(width: 960, height: 600))
        case "https://streamdeck-canvas.example":
            HTTPResponse(status: 200, headers: frameOptions.map { ["X-Frame-Options": $0] } ?? [:],
                         body: Data(#"<html><head><link rel="icon" href="/icon.png"></head></html>"#.utf8))
        case "https://streamdeck-canvas.example/icon.png":
            HTTPResponse(status: iconStatus, body: TestImages.png(width: 128, height: 128))
        default:
            HTTPResponse(status: 404)
        }
    }
}

/// A render that writes a 1440×900 picture.
private let paintingRender: @Sendable (URL, URL) async throws -> Void = { _, file in
    try TestImages.png(width: 1440, height: 900, topRows: 100).write(to: file)
}

@Suite("Picture jobs")
struct PictureJobsTests {
    @Test func fetchesScreenshotFaviconFramingAndThumbnail() async throws {
        let test = TestContext(http: workingSite(frameOptions: "SAMEORIGIN"))
        let site = Fixtures.site()
        try test.cache([site])
        await PictureJobs(context: test.context).fetchMissing()

        let store = PictureStore(context: test.context)
        #expect(store.picture(for: site)?.lastPathComponent == "screenshot.png")
        #expect(store.thumbnail(for: site)?.lastPathComponent == "thumbnail-screenshot.png")
        #expect(store.allowsFraming(site) == false)
        let favicon = try #require(store.favicon(for: site))
        #expect(favicon.lastPathComponent == "favicon.png")
        #expect(TestImages.image(at: favicon)?.width == 64)
        let thumbnail = try #require(store.thumbnail(for: site).flatMap(TestImages.image(at:)))
        #expect(thumbnail.width == 320 && thumbnail.height == 200)
        #expect(store.picture(for: site).flatMap(TestImages.image(at:))?.width == 960)
    }

    @Test func faviconsAndPagesAreFetchedAsABrowser() async throws {
        let http = workingSite()
        let test = TestContext(http: http)
        try test.cache([Fixtures.site()])
        await PictureJobs(context: test.context).fetchMissing()
        let favicon = try #require(http.requests.first { $0.url.path == "/icon.png" })
        #expect(favicon.headers["User-Agent"]?.contains("Safari") == true)
    }

    @Test func afterTheFirstVisitNothingIsFetchedAgain() async throws {
        let http = workingSite()
        let test = TestContext(http: http)
        try test.cache([Fixtures.site()])
        await PictureJobs(context: test.context).fetchMissing()
        let first = http.requests.count
        await PictureJobs(context: test.context).fetchMissing()
        #expect(http.requests.count == first)
        #expect(!PictureStore(context: test.context).startPicturesJobIfNeeded(for: [Fixtures.site()]))
    }

    @Test func failedDownloadsAreRetriedAfter24Hours() async throws {
        let http = FakeHTTP()
        let test = TestContext(http: http)
        let site = Fixtures.site()
        try test.cache([site])
        let screenshots = { http.requests.filter { $0.url.host == "d33wubrfki0l68.cloudfront.net" }.count }

        await PictureJobs(context: test.context).fetchMissing()
        #expect(screenshots() == 1)
        #expect(PictureStore(context: test.context).picture(for: site) == nil)

        test.advance(by: 23 * 3600)
        await PictureJobs(context: test.context).fetchMissing()
        #expect(screenshots() == 1)
        #expect(!PictureStore(context: test.context).startPicturesJobIfNeeded(for: [site]))

        test.advance(by: 2 * 3600)
        #expect(PictureStore(context: test.context).startPicturesJobIfNeeded(for: [site]))
        await PictureJobs(context: test.context).fetchMissing()
        #expect(screenshots() == 2)
    }

    @Test func certificateProblemsAreRetriedWithoutChecksExceptForFraming() async throws {
        let http = FakeHTTP { request in
            guard request.acceptsAnyCertificate else { throw URLError(.serverCertificateUntrusted) }
            return HTTPResponse(status: 200, body: TestImages.png(width: 960, height: 600))
        }
        let test = TestContext(http: http)
        let site = Fixtures.site()
        try test.cache([site])
        await PictureJobs(context: test.context).fetchMissing()
        let store = PictureStore(context: test.context)
        #expect(store.picture(for: site) != nil)
        #expect(store.favicon(for: site) != nil)
        #expect(store.allowsFraming(site) == false)
        let framing = http.requests.filter { $0.url.absoluteString == "https://streamdeck-canvas.example" && $0.headers["Accept"] == "text/html" }
        #expect(framing.count == 1 && framing.allSatisfy { !$0.acceptsAnyCertificate })
    }

    @Test func aDeclaredIconThatFailsFallsBackToWellKnownAddresses() async throws {
        let http = FakeHTTP { request in
            switch request.url.path {
            case "/favicon.ico": HTTPResponse(status: 200, body: TestImages.png(width: 32, height: 32))
            case "/icon.png": HTTPResponse(status: 200, body: Data("<!doctype html><html></html>".utf8))
            default: HTTPResponse(status: 200, body: Data(#"<link rel="icon" href="/icon.png">"#.utf8))
            }
        }
        let test = TestContext(http: http)
        let site = Fixtures.site()
        try test.cache([site])
        await PictureJobs(context: test.context).fetchMissing()
        #expect(PictureStore(context: test.context).favicon(for: site).flatMap(TestImages.image(at:))?.width == 32)
    }

    @Test func svgFaviconsAreKeptAsSVG() async throws {
        let svg = Data(#"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"/>"#.utf8)
        let http = FakeHTTP { request in
            request.url.path == "/i.svg"
                ? HTTPResponse(status: 200, body: svg)
                : HTTPResponse(status: 200, body: Data(#"<link rel="icon" href="/i.svg">"#.utf8))
        }
        let test = TestContext(http: http)
        let site = Fixtures.site()
        try test.cache([site])
        await PictureJobs(context: test.context).fetchMissing()
        let favicon = try #require(PictureStore(context: test.context).favicon(for: site))
        #expect(favicon.pathExtension == "svg")
        #expect(try Data(contentsOf: favicon) == svg)
    }

    @Test func aNewDeployFetchesEverythingAgainAndOldFilesAreDeleted() async throws {
        let test = TestContext(http: workingSite())
        var site = Fixtures.site()
        let gone = Fixtures.site(id: "gone")
        try test.cache([site, gone])
        await PictureJobs(context: test.context).fetchMissing()
        let oldFolder = try #require(PictureStore(context: test.context).picture(for: site)).deletingLastPathComponent()
        let goneFolder = try #require(PictureStore(context: test.context).picture(for: gone)).deletingLastPathComponent()

        site.publishedDeploy = Fixtures.deploy(id: "d2")
        try test.cache([site])
        let store = PictureStore(context: test.context)
        #expect(store.picture(for: site) == nil)
        #expect(store.favicon(for: site) == nil)
        #expect(store.startPicturesJobIfNeeded(for: [site]))
        await PictureJobs(context: test.context).fetchMissing()

        #expect(store.picture(for: site) != nil)
        #expect(store.favicon(for: site) != nil)
        #expect(!FileManager.default.fileExists(atPath: oldFolder.path))
        #expect(!FileManager.default.fileExists(atPath: goneFolder.deletingLastPathComponent().path))
    }

    @Test func resetDuringDownloadDoesNotRecreatePictures() async throws {
        let test = TestContext()
        try test.cache([Fixtures.site()])
        var context = test.context
        context.http = FakeHTTP { _ in
            try test.paths.forgetAccount()
            return HTTPResponse(status: 200, body: TestImages.png(width: 32, height: 32))
        }
        await PictureJobs(context: context).fetchMissing()
        #expect(!FileManager.default.fileExists(atPath: test.paths.accountFolder.path))
    }

    @Test func unpublishedSitesHaveNoPictures() async throws {
        let http = workingSite()
        let test = TestContext(http: http)
        var site = Fixtures.site()
        site.publishedDeploy = nil
        try test.cache([site])
        await PictureJobs(context: test.context).fetchMissing()
        #expect(http.requests.isEmpty)
        let store = PictureStore(context: test.context)
        #expect(store.picture(for: site) == nil && store.thumbnail(for: site) == nil)
        #expect(!store.startRenderJobIfNeeded(site))
    }
}

@Suite("Renders")
struct RenderTests {
    @Test func aRenderReplacesTheScreenshotAndGetsANewThumbnailName() async throws {
        let test = TestContext(http: workingSite())
        let site = Fixtures.site()
        try test.cache([site])
        await PictureJobs(context: test.context).fetchMissing()
        let store = PictureStore(context: test.context)
        let screenshotThumbnail = try #require(store.thumbnail(for: site))

        #expect(store.startRenderJobIfNeeded(site))
        #expect(test.jobs.launched == [.render(siteID: site.id)])
        await PictureJobs(context: test.context, renderPage: paintingRender).render(siteID: site.id)

        #expect(store.picture(for: site)?.lastPathComponent == "render.png")
        let thumbnail = try #require(store.thumbnail(for: site))
        #expect(thumbnail != screenshotThumbnail)
        #expect(TestImages.colour(of: try #require(TestImages.image(at: thumbnail)), x: 160, y: 2) == (255, 0, 0))

        // Once per deploy.
        #expect(!store.startRenderJobIfNeeded(site))
        // The tidy drops the replaced thumbnail.
        await PictureJobs(context: test.context).fetchMissing()
        #expect(!FileManager.default.fileExists(atPath: screenshotThumbnail.path))
    }

    @Test func resetDuringRenderDoesNotRecreatePictures() async throws {
        let test = TestContext()
        let site = Fixtures.site()
        try test.cache([site])
        await PictureJobs(context: test.context) { url, file in
            try test.paths.forgetAccount()
            try await paintingRender(url, file)
        }.render(siteID: site.id)
        #expect(!FileManager.default.fileExists(atPath: test.paths.accountFolder.path))
    }

    @Test func aFailedRenderIsRetriedAfter24Hours() async throws {
        let test = TestContext()
        let site = Fixtures.site()
        try test.cache([site])
        let store = PictureStore(context: test.context)
        #expect(store.startRenderJobIfNeeded(site))
        await PictureJobs(context: test.context) { _, _ in throw PictureError.timedOut }.render(siteID: site.id)
        #expect(store.picture(for: site) == nil)
        #expect(!store.startRenderJobIfNeeded(site))
        test.advance(by: 25 * 3600)
        #expect(store.startRenderJobIfNeeded(site))
    }

    @Test func onlyTheNewestSelectionWaits() async throws {
        let test = TestContext()
        let sites = ["a", "b", "c"].map { Fixtures.site(id: $0) }
        try test.cache(sites)
        let store = PictureStore(context: test.context)
        for site in sites { #expect(store.startRenderJobIfNeeded(site)) }

        let rendered = Locked<[URL]>([])
        await PictureJobs(context: test.context) { url, file in
            rendered.withLock { $0.append(file) }
            try await paintingRender(url, file)
        }.render(siteID: "a")
        #expect(rendered.value.map { $0.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent } == ["c"])
    }

    @Test func aJobFindingTheRendererBusyLeavesItsRequestQueued() async throws {
        let test = TestContext()
        try test.cache([Fixtures.site(id: "a"), Fixtures.site(id: "b")])
        let queue = RenderQueue(paths: test.paths)
        let order = Locked<[String]>([])
        await PictureJobs(context: test.context) { url, file in
            let site = file.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
            order.withLock { $0.append(site) }
            if site == "a" {
                // The user selects b meanwhile; its job finds the renderer busy and exits.
                try queue.request("b")
                await PictureJobs(context: test.context, renderPage: paintingRender).render(siteID: "b")
            }
            try await paintingRender(url, file)
        }.render(siteID: "a")
        #expect(order.value == ["a", "b"])
        #expect(queue.isEmpty)
    }

    @Test func aRunningRenderKeepsTheWindowPulsing() async throws {
        let test = TestContext()
        let site = Fixtures.site()
        try test.cache([site])
        let store = PictureStore(context: test.context)
        let pulsing = Locked(false)
        let queue = RenderQueue(paths: test.paths)
        try queue.request(site.id)
        await queue.drain { _ in
            pulsing.withLock { $0 = store.startPicturesJobIfNeeded(for: []) }
        }
        #expect(pulsing.value)
        #expect(test.jobs.launched.isEmpty)
    }
}

@Suite("Picture store")
struct PictureStoreTests {
    @Test func startsThePicturesJobOnlyWhenSomethingIsMissing() throws {
        let test = TestContext()
        let store = PictureStore(context: test.context)
        #expect(store.startPicturesJobIfNeeded(for: [Fixtures.site()]))
        #expect(test.jobs.launched == [.pictures])
    }

    @Test func aRunningPicturesJobIsNotStartedTwice() async throws {
        let test = TestContext()
        let store = PictureStore(context: test.context)
        await JobLock(.pictures, paths: test.paths).tryHolding {
            #expect(store.startPicturesJobIfNeeded(for: [Fixtures.site()]))
        }
        #expect(test.jobs.launched.isEmpty)
    }

    @Test func demoModeFetchesNothingAndShowsPicturesOnly() async throws {
        let test = TestContext(demo: true, http: workingSite())
        let site = Fixtures.site()
        try test.cache([site])
        let store = PictureStore(context: test.context)
        #expect(!store.startPicturesJobIfNeeded(for: [site]))
        #expect(!store.startRenderJobIfNeeded(site))
        await PictureJobs(context: test.context).fetchMissing()
        #expect(test.jobs.launched.isEmpty && test.http.requests.isEmpty)
        #expect(store.allowsFraming(site) == false)
    }

    @Test func demoPicturesAreAdopted() throws {
        let test = TestContext(demo: true)
        let site = Fixtures.site()
        let screenshot = test.folder.appending(path: "shot.png")
        let favicon = test.folder.appending(path: "icon.png")
        try TestImages.png(width: 1440, height: 900).write(to: screenshot)
        try TestImages.png(width: 256, height: 256).write(to: favicon)

        let store = PictureStore(context: test.context)
        try store.adoptDemoPictures(screenshot: screenshot, favicon: favicon, for: site)
        #expect(store.picture(for: site) != nil)
        #expect(store.thumbnail(for: site).flatMap(TestImages.image(at:))?.width == 320)
        #expect(store.favicon(for: site).flatMap(TestImages.image(at:))?.width == 64)
        #expect(store.picture(for: site)?.path.hasPrefix(test.paths.accountFolder.path) == true)
    }
}
