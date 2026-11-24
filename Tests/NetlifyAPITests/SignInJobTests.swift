import Foundation
import NetlifyAPI
import NetlifyCore
import NetlifyTesting
import Testing

@Suite("Sign-in")
struct SignInJobTests {
    @Test func approvedInTheBrowser() async throws {
        let polls = Locked(0)
        let http = FakeHTTP { request in
            switch request.endpoint {
            case "POST /api/v1/oauth/tickets": return .json(#"{"id": "t1", "authorized": false}"#, status: 201)
            case "GET /api/v1/oauth/tickets/t1":
                let count = polls.withLock { $0 += 1; return $0 }
                return .json(#"{"id": "t1", "authorized": \#(count == 3)}"#)
            case "POST /api/v1/oauth/tickets/t1/exchange": return .json(#"{"access_token": "new-token", "token_type": "Bearer"}"#)
            default: return HTTPResponse(status: 404)
            }
        }
        let test = TestContext(token: nil, settings: Settings(clientID: "public-id"), http: http)
        try test.cache([Fixtures.site()])
        let sleeps = Locked<[Duration]>([])
        let refreshed = Locked<(token: String?, cacheGone: Bool, progressGone: Bool)?>(nil)
        let refresher = FakeRefresher {
            refreshed.withLock {
                $0 = (try? test.tokens.read(), SiteCache(paths: test.paths).read() == nil, SignInProgress.read(paths: test.paths) == nil)
            }
            try? test.cache([Fixtures.site()])
        }
        let progressWhileWaiting = Locked<SignInProgress?>(nil)
        var context = Self.counting(sleeps, in: test)
        context.sleep = { duration in
            sleeps.withLock { $0.append(duration) }
            progressWhileWaiting.withLock { $0 = SignInProgress.read(paths: test.paths) }
        }

        try Self.clickSignIn(test)
        await SignInJob(context: context, refresher: refresher, attempt: "a1").run()

        let create = try #require(http.requests.first)
        #expect(create.query("client_id") == "public-id")
        #expect(create.headers["Authorization"] == nil)
        #expect(test.tokens.current == "new-token")
        #expect(refresher.refreshes == 1)
        #expect(refreshed.value?.token == "new-token")
        #expect(refreshed.value?.cacheGone == true)
        #expect(refreshed.value?.progressGone == true)
        #expect(progressWhileWaiting.value?.stage == .connecting)
        #expect(sleeps.value == [.seconds(2), .seconds(2), .seconds(2)])
        #expect(test.system.calls == [
            .opened(URL(string: "https://app.netlify.com/authorize?response_type=ticket&ticket=t1")!),
            .reopenedWindow,
        ])
    }

    @Test func aFailedFirstRefreshIsLeftToTheWindow() async throws {
        let http = FakeHTTP { request in
            switch request.endpoint {
            case "POST /api/v1/oauth/tickets": .json(#"{"id": "t1", "authorized": true}"#, status: 201)
            case "GET /api/v1/oauth/tickets/t1": .json(#"{"id": "t1", "authorized": true}"#)
            case "POST /api/v1/oauth/tickets/t1/exchange": .json(#"{"access_token": "new-token"}"#)
            default: HTTPResponse(status: 404)
            }
        }
        let test = TestContext(token: nil, http: http)
        let refresher = FakeRefresher {
            try? SiteCache(paths: test.paths).write(problem: .failed(message: "The Internet connection appears to be offline."))
        }

        try Self.clickSignIn(test)
        await SignInJob(context: test.context, refresher: refresher, attempt: "a1").run()

        // The window shows the refresh problem itself ("Couldn't load your Netlify sites", with Retry).
        #expect(test.tokens.current == "new-token")
        #expect(SignInProgress.read(paths: test.paths) == nil)
        #expect(test.system.calls.last == .reopenedWindow)
    }

    @Test func deniedOrExpired() async throws {
        let test = TestContext(token: nil, http: FakeHTTP { request in
            request.method == .post ? .json(#"{"id": "t1"}"#) : .json(#"{"code": 404, "message": "Not Found"}"#, status: 404)
        })
        let refresher = FakeRefresher()

        try Self.clickSignIn(test)
        await SignInJob(context: test.context, refresher: refresher, attempt: "a1").run()

        #expect(test.tokens.current == nil)
        #expect(refresher.refreshes == 0)
        #expect(Self.failure(test) == "Sign-in was denied or expired.")
        #expect(test.system.calls.last == .reopenedWindow)
    }

    @Test func givesUpAfterFiveMinutes() async throws {
        let test = TestContext(token: nil, http: FakeHTTP { _ in .json(#"{"id": "t1", "authorized": false}"#) })
        let sleeps = Locked<[Duration]>([])

        try Self.clickSignIn(test)
        await SignInJob(context: Self.counting(sleeps, in: test), refresher: FakeRefresher(), attempt: "a1").run()

        #expect(sleeps.value.reduce(.zero, +) == .seconds(300))
        #expect(test.http.requests.filter { $0.method == .get }.count == 150)
        #expect(test.tokens.current == nil)
        #expect(Self.failure(test) == "Sign-in timed out.")
        #expect(!test.system.calls.contains(.reopenedWindow))
    }

    @Test func keepsWaitingThroughAFailedCheck() async throws {
        let polls = Locked(0)
        let test = TestContext(token: nil, http: FakeHTTP { request in
            if request.method == .post {
                return request.url.lastPathComponent == "exchange" ? .json(#"{"access_token": "new-token"}"#) : .json(#"{"id": "t1"}"#)
            }
            let count = polls.withLock { $0 += 1; return $0 }
            if count == 1 { throw URLError(.networkConnectionLost) }
            if count == 2 { return HTTPResponse(status: 502) }
            return .json(#"{"id": "t1", "authorized": true}"#)
        })

        try Self.clickSignIn(test)
        await SignInJob(context: test.context, refresher: FakeRefresher(), attempt: "a1").run()

        #expect(test.tokens.current == "new-token")
        #expect(test.system.calls.last == .reopenedWindow)
    }

    @Test func netlifyUnavailable() async throws {
        let test = TestContext(token: nil, http: FakeHTTP { _ in HTTPResponse(status: 500) })

        try Self.clickSignIn(test)
        await SignInJob(context: test.context, refresher: FakeRefresher(), attempt: "a1").run()

        // The window is still open (the browser never opened), so it isn't reopened.
        #expect(Self.failure(test) == "Sign-in failed: Netlify answered 500.")
        #expect(test.system.calls.isEmpty)
    }

    @Test func aFailedExchangeSavesNothing() async throws {
        let test = TestContext(token: "old", http: FakeHTTP { request in
            switch request.endpoint {
            case "POST /api/v1/oauth/tickets": .json(#"{"id": "t1"}"#)
            case "GET /api/v1/oauth/tickets/t1": .json(#"{"id": "t1", "authorized": true}"#)
            default: .json(#"{"message": "Ticket already exchanged"}"#, status: 422)
            }
        })
        try test.cache([Fixtures.site()])

        try Self.clickSignIn(test)
        await SignInJob(context: test.context, refresher: FakeRefresher(), attempt: "a1").run()

        #expect(test.tokens.current == "old")
        #expect(SiteCache(paths: test.paths).read() != nil)
        #expect(Self.failure(test) == "Sign-in failed: Netlify answered 422: Ticket already exchanged")
    }

    @Test func cancelStopsTheWaitAndRecordsNothing() async throws {
        let test = TestContext(token: nil, http: FakeHTTP { request in
            request.method == .post ? .json(#"{"id": "t1"}"#) : .json(#"{"id": "t1", "authorized": false}"#)
        })
        var context = test.context
        context.sleep = { _ in SignInProgress.clear(paths: test.paths) }

        try Self.clickSignIn(test)
        await SignInJob(context: context, refresher: FakeRefresher(), attempt: "a1").run()

        #expect(test.http.requests.filter { $0.method == .get }.isEmpty)
        #expect(SignInProgress.read(paths: test.paths) == nil)
        #expect(test.tokens.current == nil)
        #expect(!test.system.calls.contains(.reopenedWindow))
    }

    @Test func tryAgainReplacesTheOlderAttempt() async throws {
        let test = TestContext(token: nil, http: FakeHTTP { request in
            request.method == .post ? .json(#"{"id": "t1"}"#) : .json(#"{"id": "t1", "authorized": true}"#)
        })
        try SignInProgress(attempt: "a2", stage: .connecting, updatedAt: Fixtures.now).write(paths: test.paths)

        await SignInJob(context: test.context, refresher: FakeRefresher(), attempt: "a1").run()

        #expect(test.http.requests.isEmpty)
        #expect(SignInProgress.read(paths: test.paths)?.attempt == "a2")
        #expect(test.tokens.current == nil)
    }

    @Test func cancellationOrRetryDuringExchangeCannotSaveTheOldToken() async throws {
        for retry in [false, true] {
            let test = TestContext(token: nil)
            var context = test.context
            context.http = FakeHTTP { request in
                switch request.endpoint {
                case "POST /api/v1/oauth/tickets": return .json(#"{"id": "t1"}"#)
                case "GET /api/v1/oauth/tickets/t1": return .json(#"{"id": "t1", "authorized": true}"#)
                default:
                    if retry {
                        try SignInProgress(attempt: "a2", stage: .connecting, updatedAt: Fixtures.now).write(paths: test.paths)
                    } else {
                        SignInProgress.clear(paths: test.paths)
                    }
                    return .json(#"{"access_token": "stale-token"}"#)
                }
            }
            try Self.clickSignIn(test)
            await SignInJob(context: context, refresher: FakeRefresher(), attempt: "a1").run()
            #expect(test.tokens.current == nil)
            #expect(SignInProgress.read(paths: test.paths)?.attempt == (retry ? "a2" : nil))
            #expect(!test.system.calls.contains(.reopenedWindow))
        }
    }

    @Test func startedByHandItRecordsItsOwnAttempt() async {
        let test = TestContext(token: nil, http: FakeHTTP { _ in HTTPResponse(status: 500) })
        await SignInJob(context: test.context, refresher: FakeRefresher()).run()
        #expect(Self.failure(test) == "Sign-in failed: Netlify answered 500.")
    }

    /// What the window does on Sign in: record attempt `a1` as connecting.
    private static func clickSignIn(_ test: TestContext) throws {
        try SignInProgress(attempt: "a1", stage: .connecting, updatedAt: Fixtures.now).write(paths: test.paths)
    }

    /// The failure the window will show, or nil.
    private static func failure(_ test: TestContext) -> String? {
        let progress = SignInProgress.read(paths: test.paths)
        return progress?.stage == .failed ? progress?.message : nil
    }

    /// The test's context, with a sleep that records how long it was asked to wait.
    private static func counting(_ sleeps: Locked<[Duration]>, in test: TestContext) -> Context {
        var context = test.context
        context.sleep = { duration in sleeps.withLock { $0.append(duration) } }
        return context
    }
}
