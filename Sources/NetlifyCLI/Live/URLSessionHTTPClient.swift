import Foundation
import NetlifyCore

/// HTTPClient on URLSession: a time limit for the whole exchange, a byte limit (stop reading early), and a separate
/// session that accepts any certificate for requests that ask for it. Sends a default User-Agent unless the request
/// sets one. Ephemeral sessions: no cookies or cache are kept on disk.
struct URLSessionHTTPClient: HTTPClient {
    private static let checkedSession = URLSession(configuration: configuration)
    private static let anyCertificateSession = URLSession(configuration: configuration, delegate: AnyCertificateDelegate(), delegateQueue: nil)

    private static var configuration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpAdditionalHeaders = ["User-Agent": HTTPRequest.workflowUserAgent]
        return configuration
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let session = request.acceptsAnyCertificate ? Self.anyCertificateSession : Self.checkedSession
        let urlRequest = Self.urlRequest(for: request)
        return try await Self.withTimeLimit(request.timeout) {
            if let limit = request.byteLimit {
                let (bytes, response) = try await session.bytes(for: urlRequest)
                defer { bytes.task.cancel() }
                return try Self.response(response, body: try await Self.read(bytes, limit: limit))
            } else {
                let (body, response) = try await session.data(for: urlRequest)
                return try Self.response(response, body: body)
            }
        }
    }

    /// The URLRequest for `request`; the time limit also bounds each wait for data.
    static func urlRequest(for request: HTTPRequest) -> URLRequest {
        var urlRequest = URLRequest(url: request.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: request.timeout)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        return urlRequest
    }

    /// At most `limit` bytes of the body.
    private static func read(_ bytes: URLSession.AsyncBytes, limit: Int) async throws -> Data {
        var body = Data()
        body.reserveCapacity(min(limit, 1 << 20))
        guard limit > 0 else { return body }
        for try await byte in bytes {
            body.append(byte)
            if body.count >= limit { break }
        }
        return body
    }

    private static func response(_ response: URLResponse, body: Data) throws -> HTTPResponse {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        var headers: [String: String] = [:]
        for case let (name as String, value as String) in http.allHeaderFields {
            headers[name] = value
        }
        return HTTPResponse(status: http.statusCode, headers: headers, body: body)
    }

    /// `operation`'s result, or `URLError(.timedOut)` once `seconds` have passed (the operation is cancelled).
    private static func withTimeLimit<T: Sendable>(_ seconds: TimeInterval, _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask(operation: operation)
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
}

/// Trusts whatever certificate a server presents. Only for picture and favicon downloads from custom domains that
/// serve a certificate for another host name; never used for the Netlify API.
private final class AnyCertificateDelegate: NSObject, URLSessionDelegate, Sendable {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else { return (.performDefaultHandling, nil) }
        return (.useCredential, URLCredential(trust: trust))
    }
}
