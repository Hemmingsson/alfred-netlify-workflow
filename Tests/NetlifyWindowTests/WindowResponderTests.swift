import Foundation
import NetlifyCore
import NetlifyTesting
import Testing
@testable import NetlifyWindow

@Suite("The window's replies")
struct WindowResponderTests {
    let test: TestContext
    let refresher: FakeRefresher
    let pictures: FakePictures

    init(token: String? = "token", demo: Bool = false, pictures: FakePictures = FakePictures(), onRefresh: @escaping @Sendable () -> Void = {}) {
        test = TestContext(token: token, demo: demo)
        self.pictures = pictures
        refresher = FakeRefresher(onRefresh: onRefresh)
    }

    init() {
        self.init(token: "token")
    }

    var responder: WindowResponder {
        WindowResponder(context: test.context, refresher: refresher, pictures: pictures, timeZone: TimeZone(identifier: "UTC")!)
    }

    func reply(_ command: WindowCommand) async throws -> ReplyJSON {
        try ReplyJSON(await responder.reply(to: command))
    }

    func sites(_ count: Int) -> [Site] {
        (1...count).map { Fixtures.site(id: "s\($0)") }
    }

    // MARK: Opening

    @Test func signedOutSaysSoAndOffersSignIn() async throws {
        let window = WindowResponderTests(token: nil)
        let reply = try await window.reply(.load(query: ""))
        #expect(reply.emptyTitle == "Not signed in to Netlify.")
        #expect(reply.emptyDetail == "Click Sign in to connect your account.")
        #expect(reply.update("emptyPane")?["hidden"] as? Bool == false)
        #expect(reply.update("mainContent")?["hidden"] as? Bool == true)
        #expect(reply.rows.isEmpty)
        #expect(reply.update("detailPane")?["hidden"] as? Bool == true)
        #expect(reply.emptyAction == "Sign in to Netlify")
        #expect(reply.variables["emptyAction"] == "sign-in")
        #expect(reply.update("connectingButtons")?["hidden"] as? Bool == true)
        #expect(reply.pulseInterval == 0)
        #expect(window.test.jobs.launched.isEmpty)
    }

    @Test func aRejectedSignInHidesTheCachedList() async throws {
        try test.cache(sites(2))
        try SiteCache(paths: test.paths).write(problem: .signInRejected)
        let reply = try await reply(.load(query: ""))
        #expect(reply.emptyTitle == "Netlify rejected the saved sign-in.")
        #expect(reply.emptyDetail == "Click Sign in to connect again.")
        #expect(reply.rows.isEmpty)
        #expect(reply.emptyAction == "Sign in to Netlify")
    }

    // MARK: Signing in

    @Test func signInStartsTheJobAndShowsConnectingAtOnce() async throws {
        let window = WindowResponderTests(token: nil)
        let reply = try await window.reply(.signIn)
        let progress = try #require(SignInProgress.read(paths: window.test.paths))
        #expect(progress.stage == .connecting)
        #expect(window.test.jobs.launched == [.signIn(attempt: progress.attempt)])
        #expect(reply.emptyTitle == "Connecting to Netlify…")
        #expect(reply.emptyDetail == "Approve access in your browser. This window updates by itself.")
        #expect(reply.update("emptyActionBox")?["hidden"] as? Bool == true)
        #expect(reply.update("connectingButtons")?["hidden"] as? Bool == false)
        #expect(reply.pulseInterval == 1.5)
    }

    /// The window was closed while the browser was open, and reopened.
    @Test func reopenedWhileWaitingForTheBrowserItStillSaysConnecting() async throws {
        let window = WindowResponderTests(token: nil)
        _ = try await window.reply(.signIn)
        window.test.advance(by: 60)
        try await JobLock(.signIn(attempt: nil), paths: window.test.paths).tryHolding {
            let reply = try await window.reply(.load(query: ""))
            #expect(reply.emptyTitle == "Connecting to Netlify…")
            #expect(reply.pulseInterval == 1.5)
        }
    }

    @Test func aConnectingRecordWithNoJobBehindItIsIgnored() async throws {
        let window = WindowResponderTests(token: nil)
        _ = try await window.reply(.signIn)
        window.test.advance(by: SignInProgress.startGrace + 1)
        let reply = try await window.reply(.pulse(fingerprint: "", selectedSiteID: "", previewSource: ""))
        #expect(reply.emptyTitle == "Not signed in to Netlify.")
    }

    @Test func tryAgainStartsANewAttempt() async throws {
        let window = WindowResponderTests(token: nil)
        _ = try await window.reply(.signIn)
        let first = SignInProgress.read(paths: window.test.paths)?.attempt
        _ = try await window.reply(.signIn)
        let second = SignInProgress.read(paths: window.test.paths)?.attempt
        #expect(first != second)
        #expect(window.test.jobs.launched == [.signIn(attempt: first), .signIn(attempt: second)])
    }

    @Test func cancelGoesBackToSignedOut() async throws {
        let window = WindowResponderTests(token: nil)
        _ = try await window.reply(.signIn)
        let reply = try await window.reply(.cancelSignIn)
        #expect(SignInProgress.read(paths: window.test.paths) == nil)
        #expect(reply.emptyTitle == "Not signed in to Netlify.")
        #expect(reply.pulseInterval == 0)
    }

    /// The pulse notices the token: "Loading your Netlify sites…", with no notification needed.
    @Test func theTokenArrivingSwitchesToLoadingByItself() async throws {
        let window = WindowResponderTests(token: nil)
        _ = try await window.reply(.signIn)
        try window.test.tokens.save("new-token")
        SignInProgress.clear(paths: window.test.paths)
        let reply = try await window.reply(.pulse(fingerprint: "e", selectedSiteID: "", previewSource: ""))
        #expect(reply.emptyTitle == "Loading your Netlify sites…")
        #expect(reply.update("emptyActionBox")?["hidden"] as? Bool == true)
        #expect(reply.update("emptyDetail")?["hidden"] as? Bool == true)
        #expect(reply.pulseInterval == 1.5)
    }

    @Test func aFailedSignInSaysWhyAndOffersSignInAgain() async throws {
        let window = WindowResponderTests(token: nil)
        try SignInProgress(attempt: "a1", stage: .failed, message: "Sign-in was denied or expired.", updatedAt: Fixtures.now).write(paths: window.test.paths)
        let reply = try await window.reply(.load(query: ""))
        #expect(reply.emptyTitle == "Sign-in was denied or expired.")
        #expect(reply.emptyDetail == "Click Sign in to try again.")
        #expect(reply.emptyAction == "Sign in to Netlify")
        #expect(reply.pulseInterval == 0)
    }

    @Test func demoModeHasNoSignIn() async throws {
        let window = WindowResponderTests(demo: true)
        try window.test.cache(sites(1))
        _ = try await window.reply(.signIn)
        #expect(window.test.jobs.launched.isEmpty)
        #expect(SignInProgress.read(paths: window.test.paths) == nil)
    }

    // MARK: Signing out

    @Test func signOutForgetsTheTokenAndTheAccountAndSaysSoInTheWindow() async throws {
        try test.cache(sites(2))
        let pictures = test.paths.picturesFolder
        try FileManager.default.createDirectory(at: pictures, withIntermediateDirectories: true)
        let reply = try await reply(.signOut)
        #expect(test.tokens.current == nil)
        #expect(!FileManager.default.fileExists(atPath: test.paths.sitesFile.path))
        #expect(!FileManager.default.fileExists(atPath: pictures.path))
        #expect(reply.emptyTitle == "Not signed in to Netlify.")
        #expect(reply.rows.isEmpty)
        #expect(reply.object["finish"] == nil)
        #expect(test.system.calls.isEmpty)
    }

    @Test func demoModeHasNoAccountToSignOutOf() async throws {
        let window = WindowResponderTests(token: "secret", demo: true)
        try window.test.cache(sites(1))
        _ = try await window.reply(.signOut)
        #expect(window.test.tokens.current == "secret")
        #expect(FileManager.default.fileExists(atPath: window.test.paths.sitesFile.path))
    }

    // MARK: First run

    @Test func firstRunLoadsInTheBackgroundAndKeepsChecking() async throws {
        let reply = try await reply(.load(query: ""))
        #expect(reply.emptyTitle == "Loading your Netlify sites…")
        #expect(reply.pulseInterval == 1.5)
        #expect(test.jobs.launched == [.refresh])
    }

    @Test func aFailedFirstFetchShowsTheReasonWithRetryAndDoesNotLoop() async throws {
        try SiteCache(paths: test.paths).write(problem: .failed(message: "The Internet connection appears to be offline."))
        let pulse = try await reply(.pulse(fingerprint: "", selectedSiteID: "", previewSource: ""))
        #expect(pulse.emptyTitle == "Couldn’t load your Netlify sites.")
        #expect(pulse.emptyDetail == "The Internet connection appears to be offline.")
        #expect(pulse.emptyAction == "Retry")
        #expect(pulse.variables["emptyAction"] == "retry")
        #expect(pulse.pulseInterval == 0)
        #expect(test.jobs.launched.isEmpty)
    }

    @Test func retryStartsARefreshAndShowsLoading() async throws {
        try SiteCache(paths: test.paths).write(problem: .failed(message: "offline"))
        let reply = try await reply(.retry)
        #expect(test.jobs.launched == [.refresh])
        #expect(reply.emptyTitle == "Loading your Netlify sites…")
        #expect(reply.pulseInterval == 1.5)
    }

    @Test func aWarmCacheOpensWithTheListTheFirstSiteAndItsDetail() async throws {
        try test.cache(sites(3), age: 60)
        let reply = try await reply(.load(query: ""))
        #expect(reply.rows.count == 3)
        #expect(reply.update("sites")?["placeholder"] as? String == "No matching sites")
        #expect(reply.variables["selectedSiteID"] == "s1")
        #expect(reply.update("projectName")?["text"] as? String == "dulcet-paletas-403ab7")
        #expect(reply.update("detailPane")?["hidden"] as? Bool == false)
        #expect(reply.status == "3 sites · updated 1 min ago")
        #expect((reply.object["functions"] as? [String: Any])?["ids"] as? [String: String] == ["sites": "filterdata"])
        #expect(reply.replaced("livePreview")?["src"] as? String == "about:blank")
        #expect(reply.pulseInterval == 30)
        #expect(test.jobs.launched.isEmpty)
        let filter = (reply.update("sites")?["data"] as? [String: Any])?["filter"] as? [String: String]
        #expect(filter == ["type": "basic", "args": "match", "match": "{value:searchField.text}", "matchmode": "wordmatchanyorder"])
    }

    @Test func oneSiteIsSingular() async throws {
        try test.cache(sites(1))
        #expect(try await reply(.load(query: "")).status == "1 site · updated just now")
    }

    @Test func aStaleCacheShowsAtOnceAndRefreshesInTheBackground() async throws {
        try test.cache(sites(2), age: 600)
        let reply = try await reply(.load(query: ""))
        #expect(reply.rows.count == 2)
        #expect(reply.status == "Refreshing…")
        #expect(reply.pulseInterval == 1.5)
        #expect(test.jobs.launched == [.refresh])
    }

    @Test func demoModeNeverRefreshesOrSignsIn() async throws {
        let window = WindowResponderTests(token: nil, demo: true)
        try window.test.cache([Fixtures.site()], age: 99_999)
        let reply = try await window.reply(.load(query: ""))
        #expect(reply.rows.count == 1)
        #expect(window.test.jobs.launched.isEmpty)
        _ = try await window.reply(.refresh(selectedSiteID: "s1", previewSource: "", query: ""))
        #expect(window.refresher.refreshes == 0)
    }

    @Test func untrustedTextIsDefused() async throws {
        var site = Fixtures.site()
        site.publishedDeploy?.title = "Use {var:token} here"
        try test.cache([site])
        let reply = try await reply(.load(query: ""))
        #expect(!reply.text.contains("{var:token}"))
        #expect(reply.text.contains("{\u{200B}var:token}"))
        #expect(reply.text.contains("{value:searchField.text}"))
    }

    // MARK: Pulse

    @Test func aListThatOnlyAgedIsNotResent() async throws {
        try test.cache(sites(2))
        let first = try await reply(.load(query: ""))
        let fingerprint = try #require(first.variables["fingerprint"])
        test.advance(by: 120)
        let pulse = try await reply(.pulse(fingerprint: fingerprint, selectedSiteID: "s2", previewSource: "about:blank"))
        #expect(pulse.rows.isEmpty)
        #expect(pulse.update("sites") == nil)
        #expect(pulse.status == "2 sites · updated 2 min ago")
        #expect(pulse.object["variables"] == nil)
    }

    @Test func aChangedListIsResentKeepingTheSelectionAndThePreview() async throws {
        try test.cache(sites(2))
        let fingerprint = try #require(try await reply(.load(query: "")).variables["fingerprint"])
        var changed = sites(2)
        changed[1].name = "renamed"
        try test.cache(changed)
        let pulse = try await reply(.pulse(fingerprint: fingerprint, selectedSiteID: "s2", previewSource: "about:blank"))
        #expect(pulse.rows.count == 2)
        #expect(pulse.variables["selectedSiteID"] == nil)
        #expect(pulse.variables["fingerprint"] != fingerprint)
        #expect(pulse.update("projectName")?["text"] as? String == "renamed")
        #expect(pulse.update("detailPane") == nil)
        #expect(pulse.object["replace"] == nil)
    }

    @Test func picturesStillComingSayLoadingPreviews() async throws {
        let window = WindowResponderTests(pictures: FakePictures(stillFetching: true))
        try window.test.cache(sites(2))
        let reply = try await window.reply(.load(query: ""))
        #expect(reply.status == "2 sites · updated just now · loading previews…")
        #expect(reply.pulseInterval == 1.5)
    }

    @Test func aFailedRefreshWithACacheSaysSoAndKeepsTheList() async throws {
        try test.cache(sites(2), age: 20 * 60)
        try SiteCache(paths: test.paths).write(problem: .failed(message: "offline"))
        let pulse = try await reply(.pulse(fingerprint: "", selectedSiteID: "s1", previewSource: ""))
        #expect(pulse.rows.count == 2)
        #expect(pulse.status == "Refresh failed · updated 20 min ago")
        #expect(pulse.update("statusLabel")?["tooltip"] as? String == "offline")
        #expect(test.jobs.launched.isEmpty)
    }

    @Test func framingBecomingKnownLoadsTheLivePreview() async throws {
        try test.cache(sites(1))
        let fingerprint = try #require(try await reply(.load(query: "")).variables["fingerprint"])
        let framed = WindowResponder(context: test.context, refresher: refresher, pictures: FakePictures(framing: ["s1": true]), timeZone: .gmt)
        let pulse = try ReplyJSON(await framed.reply(to: .pulse(fingerprint: fingerprint, selectedSiteID: "s1", previewSource: "about:blank")))
        let source = try #require(pulse.variables["previewSource"])
        #expect(source.hasSuffix("previews/s1.html"))
        #expect(pulse.replaced("livePreview")?["src"] as? String == source)
        #expect(pulse.replaced("livePreview")?["opacity"] as? Double == 1)
    }

    // MARK: Refresh

    @Test func refreshFetchesThenSendsTheListKeepingThePreview() async throws {
        let paths = test.paths
        let refresher = FakeRefresher(onRefresh: { try? SiteCache(paths: paths).write([Fixtures.site(id: "s1"), Fixtures.site(id: "s2")], savedAt: Fixtures.now) })
        let responder = WindowResponder(context: test.context, refresher: refresher, pictures: pictures, timeZone: .gmt)
        let reply = try ReplyJSON(await responder.reply(to: .refresh(selectedSiteID: "s2", previewSource: "about:blank", query: "")))
        #expect(refresher.refreshes == 1)
        #expect(reply.rows.count == 2)
        #expect(reply.variables["selectedSiteID"] == nil)
        #expect(reply.object["replace"] == nil)
        #expect(reply.status == "2 sites · updated just now")
        #expect(test.jobs.launched.isEmpty)
    }

    // MARK: Selection, filter, finish

    @Test func selectingAPublishedSiteStartsItsRender() async throws {
        let window = WindowResponderTests(pictures: FakePictures(startsRenders: true))
        var never = Fixtures.site(id: "s2")
        never.publishedDeploy = nil
        try window.test.cache([Fixtures.site(), never])
        #expect(try await window.reply(.selected(siteID: "s1", previewSource: "about:blank")).pulseInterval == 1.5)
        #expect(try await window.reply(.selected(siteID: "s2", previewSource: "about:blank")).object.isEmpty)
        #expect(window.pictures.renderRequests == ["s1"])
    }

    @Test func aFilterThatHidesEveryRowHidesTheDetailPane() async throws {
        #expect(try await reply(.filtered(selectedSiteID: "", query: "")).update("detailPane")?["hidden"] as? Bool == true)
        #expect(try await reply(.filtered(selectedSiteID: "s1", query: "")).update("detailPane")?["hidden"] as? Bool == false)
    }

    @Test func aSearchThatMatchesNothingHidesTheDetailPaneEvenWithAStaleSelection() async throws {
        try test.cache(sites(2))
        #expect(try await reply(.filtered(selectedSiteID: "s1", query: "zzz")).update("detailPane")?["hidden"] as? Bool == true)
        #expect(try await reply(.filtered(selectedSiteID: "s1", query: "PALETAS streamdeck")).update("detailPane")?["hidden"] as? Bool == false)
    }

    @Test func refreshKeepsTheDetailPaneHiddenWhileTheFilterHidesEveryRow() async throws {
        try test.cache(sites(2))
        let hidden = try await reply(.refresh(selectedSiteID: "", previewSource: "about:blank", query: "zzz"))
        #expect(hidden.rows.count == 2)
        #expect(hidden.update("detailPane")?["hidden"] as? Bool == true)
        #expect(hidden.variables["selectedSiteID"] == "")
        let shown = try await reply(.refresh(selectedSiteID: "s2", previewSource: "about:blank", query: "paletas"))
        #expect(shown.update("detailPane")?["hidden"] as? Bool == false)
    }

    @Test func openingWithASearchThatMatchesNothingHidesTheDetailPane() async throws {
        var other = Fixtures.site(id: "s2")
        other.name = "bland-band"
        other.customDomain = "bland.band"
        other.url = URL(string: "https://bland.band")
        try test.cache([Fixtures.site(), other])
        #expect(try await reply(.load(query: "nothing")).update("detailPane")?["hidden"] as? Bool == true)
        let band = try await reply(.load(query: "band"))
        #expect(band.update("detailPane")?["hidden"] as? Bool == false)
        #expect(band.variables["selectedSiteID"] == "s2")
    }

    @Test func selectingSwapsThePreviewOnlyWhenItHoldsAnotherPage() async throws {
        let window = WindowResponderTests(pictures: FakePictures(framing: ["s1": true, "s2": true]))
        try window.test.cache(sites(2))
        let first = try await window.reply(.selected(siteID: "s1", previewSource: "about:blank"))
        let source = try #require(first.variables["previewSource"])
        #expect(source.hasSuffix("previews/s1.html"))
        #expect(first.replaced("livePreview")?["src"] as? String == source)
        // A list update re-selects the same row: the page stays, nothing reloads.
        #expect(try await window.reply(.selected(siteID: "s1", previewSource: source)).object.isEmpty)
        let second = try await window.reply(.selected(siteID: "s2", previewSource: source))
        #expect((second.replaced("livePreview")?["src"] as? String)?.hasSuffix("previews/s2.html") == true)
    }

    @Test func untilTheFramingCheckAnswersOnlyThePictureShows() async throws {
        let window = WindowResponderTests(pictures: FakePictures(framing: ["s2": false]))
        try window.test.cache(sites(3))
        for id in ["s1", "s2"] {
            let reply = try await window.reply(.selected(siteID: id, previewSource: "/old.html"))
            #expect(reply.replaced("livePreview")?["src"] as? String == "about:blank")
            #expect(reply.replaced("livePreview")?["opacity"] as? Double == 0)
        }
        let load = try await window.reply(.load(query: ""))
        #expect(load.replaced("livePreview")?["src"] as? String == "about:blank")
        #expect(load.update("pictureView")?["image"] != nil)
    }

    @Test func returnWithNoRowsDoesNothing() async throws {
        #expect(try await reply(.finish(argument: "")).object.isEmpty)
        let open = try await reply(.finish(argument: "open:https://a.example"))
        #expect((open.object["finish"] as? [String: String])?["args"] == "open:https://a.example")
    }
}
