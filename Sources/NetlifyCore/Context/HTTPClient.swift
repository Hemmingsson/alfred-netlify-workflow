/// Sends HTTP requests. The live one uses URLSession (NetlifyCLI); tests use `FakeHTTP`.
public protocol HTTPClient: Sendable {
    /// Any answer comes back, whatever its status; only failing to get one (offline, timeout, TLS) throws.
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}
