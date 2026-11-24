import Foundation

/// What can go wrong talking to Netlify, worded for the window.
public enum NetlifyError: Error, Equatable, LocalizedError {
    /// There is no saved token.
    case signedOut
    /// Netlify answered 401 to the saved token.
    case signInRejected
    /// Any other answer that isn't 2xx.
    case status(Int, message: String)
    /// A 2xx answer we couldn't read.
    case unreadableResponse

    public var errorDescription: String? {
        switch self {
        case .signedOut: "Not signed in to Netlify."
        case .signInRejected: "Netlify rejected the saved sign-in."
        case .status(let code, let message): message.isEmpty ? "Netlify answered \(code)." : "Netlify answered \(code): \(message)"
        case .unreadableResponse: "Netlify sent something unexpected."
        }
    }
}
