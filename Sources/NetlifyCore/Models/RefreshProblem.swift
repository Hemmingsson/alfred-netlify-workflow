/// Why the last refresh didn't update the cache; the window shows it instead of a list.
public enum RefreshProblem: Codable, Equatable, Sendable {
    /// Netlify answered 401: the saved token no longer works, so the user must sign in again.
    case signInRejected
    /// Anything else (offline, Netlify down); the message is shown as is.
    case failed(message: String)
}
