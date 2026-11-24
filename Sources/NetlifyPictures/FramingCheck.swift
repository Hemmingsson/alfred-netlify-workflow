import Foundation
import NetlifyCore

/// Whether a deploy may be shown in the window's iframe, from the headers its home page is served with.
struct FramingCheck: Codable, Equatable, Sendable {
    var allowsFraming: Bool
    /// Why framing is refused, e.g. `X-Frame-Options: DENY`; nil when it is allowed.
    var reason: String?

    static let allowed = FramingCheck(allowsFraming: true)

    static func refused(_ reason: String) -> FramingCheck {
        FramingCheck(allowsFraming: false, reason: reason)
    }

    /// Judges a response's headers, whatever its status (an error page is framed under the same rules). Framing is
    /// refused by `X-Frame-Options` DENY, SAMEORIGIN or ALLOW-FROM, or by a CSP `frame-ancestors` that doesn't
    /// list `*`; the window's preview is a local page, so no other source would match it.
    init(headersOf response: HTTPResponse) {
        if let options = response.header("X-Frame-Options") {
            // Repeated headers arrive joined with ", ".
            for value in options.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces).lowercased() })
            where value == "deny" || value == "sameorigin" || value.hasPrefix("allow-from") {
                self = .refused("X-Frame-Options: \(value.uppercased())")
                return
            }
        }
        if let policy = response.header("Content-Security-Policy") {
            // Several policies are joined with ",", their directives with ";". Each policy must allow framing.
            let directives = policy.split(whereSeparator: { $0 == "," || $0 == ";" })
            for directive in directives {
                let words = directive.split(whereSeparator: \.isWhitespace)
                if let name = words.first, name.lowercased() == "frame-ancestors", !words.dropFirst().contains("*") {
                    self = .refused("Content-Security-Policy: \(words.joined(separator: " "))")
                    return
                }
            }
        }
        self = .allowed
    }

    private init(allowsFraming: Bool, reason: String? = nil) {
        self.allowsFraming = allowsFraming
        self.reason = reason
    }
}
