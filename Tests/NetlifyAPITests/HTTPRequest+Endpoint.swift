import Foundation
import NetlifyCore

extension HTTPRequest {
    /// Method and path, e.g. `GET /api/v1/sites`, for routing fake answers.
    var endpoint: String { "\(method.rawValue) \(url.path())" }

    /// One query parameter's value.
    func query(_ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }
}
