import Foundation
import NetlifyCore

/// The `sign-in` job: sign in through a Netlify OAuth ticket in the browser; no secret needed.
///
/// Holding the `sign-in` lock (waiting for an older attempt to notice it was replaced and stop): create a ticket with
/// the public `settings.clientID`, open Netlify's authorize page for it, and ask every 2 s, for up to 5 minutes,
/// whether the user approved it. A 404 means denied or expired; any other failed check is asked again. Once approved,
/// exchange the ticket for a token, forget the old account's cache, save the token, reopen the window and refresh.
///
/// Progress goes to `SignInProgress`, which the window shows; nothing is posted as a notification. The job works for
/// one attempt only and stops quietly when the window cancelled it or started another one.
public struct SignInJob: Sendable {
    static let authorizePage = URL(string: "https://app.netlify.com/authorize")!
    static let pollInterval: Duration = .seconds(2)
    static let timeout: Duration = .seconds(300)

    let context: Context
    let refresher: any SiteRefresher
    let attempt: String?

    public init(context: Context, refresher: any SiteRefresher, attempt: String? = nil) {
        self.context = context
        self.refresher = refresher
        self.attempt = attempt
    }

    private var api: APIConnection { APIConnection(http: context.http) }
    private var paths: Paths { context.paths }

    public func run() async {
        await JobLock(.signIn(attempt: nil), paths: paths).holding {
            let attempt = startAttempt()
            guard isCurrent(attempt) else { return }
            let outcome = await signIn(attempt: attempt)
            switch outcome {
            case .signedIn, .replaced:
                return
            case .denied, .timedOut, .failed:
                guard isCurrent(attempt) else { return }
                try? SignInProgress(attempt: attempt, stage: .failed, message: outcome.message, updatedAt: context.now()).writeIfCurrent(paths: paths)
                // The user was in the browser: bring the window back to say what happened. Not after a timeout,
                // when they have long moved on.
                if outcome.reopensWindow { context.system.reopenWindow() }
            }
        }
    }

    /// The attempt this job works for. Started by hand (no attempt), it records one of its own.
    private func startAttempt() -> String {
        if let attempt { return attempt }
        let attempt = UUID().uuidString
        try? SignInProgress(attempt: attempt, stage: .connecting, updatedAt: context.now()).write(paths: paths)
        return attempt
    }

    /// True while the window still waits for this attempt: not cancelled, not replaced by Try again.
    private func isCurrent(_ attempt: String) -> Bool {
        guard let progress = SignInProgress.read(paths: paths) else { return false }
        return progress.attempt == attempt && progress.stage == .connecting
    }

    private func signIn(attempt: String) async -> Outcome {
        var browserOpened = false
        do {
            let ticket: TicketResponse = try await api.post(
                APIConnection.url("oauth", "tickets", query: ["client_id": context.settings.clientID]),
                token: nil
            )
            guard isCurrent(attempt) else { return .replaced }
            context.system.open(Self.authorizePage.appending(queryItems: [
                URLQueryItem(name: "response_type", value: "ticket"),
                URLQueryItem(name: "ticket", value: ticket.id),
            ]))
            browserOpened = true
            for _ in 0..<Int(Self.timeout / Self.pollInterval) {
                try await context.sleep(Self.pollInterval)
                guard isCurrent(attempt) else { return .replaced }
                switch await state(ofTicket: ticket.id) {
                case .waiting:
                    continue
                case .denied:
                    return .denied
                case .approved:
                    return try await finish(ticketID: ticket.id, attempt: attempt)
                }
            }
            return .timedOut
        } catch {
            return .failed(reason: error.localizedDescription, browserOpened: browserOpened)
        }
    }

    private func state(ofTicket id: String) async -> TicketState {
        do {
            let ticket: TicketResponse = try await api.get(APIConnection.url("oauth", "tickets", id), token: nil)
            return ticket.authorized == true ? .approved : .waiting
        } catch NetlifyError.status(404, _) {
            return .denied
        } catch {
            return .waiting
        }
    }

    /// Exchange the approved ticket for a token and start over with the new account. The window is reopened as soon
    /// as the token is saved, so it shows "Loading your Netlify sites…" while the first refresh runs, then the list.
    private func finish(ticketID: String, attempt: String) async throws -> Outcome {
        let body: AccessTokenResponse = try await api.post(APIConnection.url("oauth", "tickets", ticketID, "exchange"), token: nil)
        guard try SignInProgress.complete(attempt: attempt, paths: paths, saveToken: {
            try context.tokens.save(body.accessToken)
        }) else { return .replaced }
        async let refreshed: Void = refresher.refresh()
        context.system.reopenWindow()
        await refreshed
        return .signedIn
    }

    /// Where a ticket is, as far as the user's approval goes.
    private enum TicketState {
        case waiting, approved, denied
    }

    /// How a sign-in ended.
    private enum Outcome: Equatable {
        case signedIn, denied, timedOut
        /// The window cancelled this attempt or started another one.
        case replaced
        case failed(reason: String, browserOpened: Bool)

        var reopensWindow: Bool {
            switch self {
            case .denied: true
            case .failed(_, let browserOpened): browserOpened
            default: false
            }
        }

        /// What the window says, above "Click Sign in to try again."
        var message: String {
            switch self {
            case .signedIn, .replaced: ""
            case .denied: "Sign-in was denied or expired."
            case .timedOut: "Sign-in timed out."
            case .failed(let reason, _): "Sign-in failed: \(reason)"
            }
        }
    }
}

/// An OAuth sign-in ticket (`/oauth/tickets`): authorized once the user approves it in the browser.
private struct TicketResponse: Decodable {
    var id: String
    var authorized: Bool?
}

/// What exchanging an approved ticket gives (`POST /oauth/tickets/{id}/exchange`).
private struct AccessTokenResponse: Decodable {
    var accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}
