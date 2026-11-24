import Foundation

/// An HTTP answer.
public struct HTTPResponse: Equatable, Sendable {
    public var status: Int
    /// Header names in lower case. Repeated headers are joined with ", ".
    public var headers: [String: String]
    public var body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { "\($0), \($1)" })
        self.body = body
    }

    /// A header's value, whatever the case of `name`.
    public func header(_ name: String) -> String? { headers[name.lowercased()] }

    public var isSuccess: Bool { (200..<300).contains(status) }
}
