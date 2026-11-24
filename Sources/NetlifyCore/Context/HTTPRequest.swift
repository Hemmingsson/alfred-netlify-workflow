import Foundation

/// One HTTP request, in the terms this app needs (simpler to build, fake and compare than URLRequest).
public struct HTTPRequest: Equatable, Sendable {
    /// Sent unless a request sets its own (picture downloads pose as a browser).
    public static let workflowUserAgent = "alfred-netlify-workflow"

    public enum Method: String, Sendable {
        case get = "GET", post = "POST"
    }

    public var method: Method
    public var url: URL
    public var headers: [String: String]
    public var body: Data?
    /// Seconds before giving up.
    public var timeout: TimeInterval
    /// Stop reading the body after this many bytes (favicon pages, images).
    public var byteLimit: Int?
    /// Accept a certificate for another host name; a few custom domains serve one. Only for pictures, never the API.
    public var acceptsAnyCertificate: Bool

    public init(
        _ method: Method = .get,
        _ url: URL,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 20,
        byteLimit: Int? = nil,
        acceptsAnyCertificate: Bool = false
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.byteLimit = byteLimit
        self.acceptsAnyCertificate = acceptsAnyCertificate
    }
}
