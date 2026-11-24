/// Why the list is empty, and what the window says instead: a message centred in the window (the list and the
/// detail pane are hidden), with the button that helps.
enum EmptyState: Equatable, Sendable {
    case signedOut
    /// Netlify answered 401 to the saved token.
    case signInRejected
    /// Sign in was clicked: creating the ticket, or waiting for approval in the browser.
    case connecting
    /// The last sign-in ended without a token (denied, expired, timed out, failed); the message says why.
    case signInFailed(String)
    /// First run: the first fetch is running.
    case loading
    /// First run: the fetch failed; Retry tries again.
    case failed(String)
    /// Sign out couldn't delete the token or the cache; the reason says why.
    case signOutFailed(String)

    /// The large first line.
    var title: String {
        switch self {
        case .signedOut: "Not signed in to Netlify."
        case .signInRejected: "Netlify rejected the saved sign-in."
        case .connecting: "Connecting to Netlify…"
        case .signInFailed(let message): message
        case .loading: "Loading your Netlify sites…"
        case .failed: "Couldn’t load your Netlify sites."
        case .signOutFailed: "Couldn’t sign out of Netlify."
        }
    }

    /// The line under it: what to do, or why.
    var detail: String {
        switch self {
        case .signedOut: "Click Sign in to connect your account."
        case .signInRejected: "Click Sign in to connect again."
        case .connecting: "Approve access in your browser. This window updates by itself."
        case .signInFailed: "Click Sign in to try again."
        case .loading: ""
        case .failed(let reason), .signOutFailed(let reason): reason
        }
    }

    /// The purple button, or nil for none.
    var action: EmptyAction? {
        switch self {
        case .signedOut, .signInRejected, .signInFailed: .signIn
        case .failed: .retry
        case .connecting, .loading, .signOutFailed: nil
        }
    }

    /// Whether the small Try again and Cancel buttons show (instead of a purple button).
    var offersCancel: Bool { self == .connecting }

    /// Whether the window keeps asking for news (something is running).
    var isBusy: Bool { self == .connecting || self == .loading }
}

/// The purple button in an empty state: its text, and the window command it runs (`scripts/ui <command>`).
enum EmptyAction: Equatable, Sendable {
    case signIn, retry

    var title: String {
        switch self {
        case .signIn: "Sign in to Netlify"
        case .retry: "Retry"
        }
    }

    var tooltip: String {
        switch self {
        case .signIn: "Open app.netlify.com to connect your account"
        case .retry: "Fetch your sites from Netlify again"
        }
    }

    /// The `WindowCommand` name the button sends.
    var command: String {
        switch self {
        case .signIn: "sign-in"
        case .retry: "retry"
        }
    }
}
