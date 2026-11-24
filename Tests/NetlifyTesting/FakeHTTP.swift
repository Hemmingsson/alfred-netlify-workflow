import Foundation
import NetlifyCore

/// An HTTPClient that answers from a handler and records every request.
public final class FakeHTTP: HTTPClient {
    public typealias Handler = @Sendable (HTTPRequest) throws -> HTTPResponse

    private let handler: Handler
    private let log = Locked<[HTTPRequest]>([])

    /// Answers 404 to everything unless a handler says otherwise.
    public init(_ handler: @escaping Handler = { _ in HTTPResponse(status: 404) }) {
        self.handler = handler
    }

    /// The requests sent so far, in order.
    public var requests: [HTTPRequest] { log.value }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        log.withLock { $0.append(request) }
        return try handler(request)
    }
}

extension HTTPResponse {
    /// A 200 (or `status`) answer with a JSON body.
    public static func json(_ text: String, status: Int = 200, headers: [String: String] = [:]) -> HTTPResponse {
        HTTPResponse(status: status, headers: headers.merging(["Content-Type": "application/json"]) { old, _ in old }, body: Data(text.utf8))
    }
}
