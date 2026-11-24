import Foundation
import NetlifyCore

/// Sends requests to the Netlify API and checks the answers: 401 becomes `.signInRejected`, any other answer that
/// isn't 2xx `.status`, and a body that doesn't decode `.unreadableResponse`.
struct APIConnection: Sendable {
    static let baseURL = URL(string: "https://api.netlify.com/api/v1")!

    let http: any HTTPClient

    /// The API address made of `path` (each part percent-encoded, so an id can't add a path segment) and `query`.
    static func url(_ path: String..., query: KeyValuePairs<String, String> = [:]) -> URL {
        let url = path.reduce(baseURL) { $0.appending(component: $1) }
        return query.isEmpty ? url : url.appending(queryItems: query.map { URLQueryItem(name: $0.key, value: $0.value) })
    }

    /// Whether `url` is on the API's own host, so it may be sent the token (a pagination link, for example).
    static func isAPIAddress(_ url: URL) -> Bool {
        url.scheme == baseURL.scheme && url.host() == baseURL.host()
    }

    /// Send a request, with the token when there is one; throws for any answer that isn't 2xx.
    func send(_ method: HTTPRequest.Method, _ url: URL, token: String?) async throws -> HTTPResponse {
        var headers = ["Accept": "application/json", "User-Agent": HTTPRequest.workflowUserAgent]
        if let token {
            headers["Authorization"] = "Bearer \(token)"
        }
        let response = try await http.send(HTTPRequest(method, url, headers: headers, body: method == .post ? Data() : nil))
        guard response.isSuccess else {
            if response.status == 401 { throw NetlifyError.signInRejected }
            let message = try? JSON.decoder.decode(ErrorResponse.self, from: response.body).message
            throw NetlifyError.status(response.status, message: message ?? "")
        }
        return response
    }

    /// GET `url` and decode the answer.
    func get<Body: Decodable>(_ url: URL, token: String?) async throws -> Body {
        try decode(await send(.get, url, token: token))
    }

    /// POST to `url` and decode the answer.
    func post<Body: Decodable>(_ url: URL, token: String?) async throws -> Body {
        try decode(await send(.post, url, token: token))
    }

    func decode<Body: Decodable>(_ response: HTTPResponse) throws -> Body {
        do {
            return try JSON.decoder.decode(Body.self, from: response.body)
        } catch {
            throw NetlifyError.unreadableResponse
        }
    }
}

/// The body of a Netlify error answer, e.g. `{"code": 422, "message": "…"}`.
private struct ErrorResponse: Decodable {
    var message: String?
}
