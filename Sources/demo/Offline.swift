import Foundation
import NetlifyCore

/// The outside world, switched off: the demo tool never fetches, signs in, starts jobs or touches the Mac.
struct Offline: HTTPClient, TokenStore, JobLauncher, SystemActions {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse { throw URLError(.notConnectedToInternet) }

    func read() throws -> String? { nil }
    func save(_ token: String) throws {}
    func delete() throws {}

    func launch(_ job: BackgroundJob) {}

    func open(_ url: URL) {}
    func copy(_ text: String) {}
    func reopenWindow() {}
}
