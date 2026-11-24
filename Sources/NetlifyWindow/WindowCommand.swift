import NetlifyCore

/// What the window asks, as `scripts/ui <name> <arguments…>` (ui.json sends these).
public enum WindowCommand: Equatable, Sendable {
    /// The window opened, with this search text: everything it shows.
    case load(query: String)
    /// Every so often: news since the list with this fingerprint. `previewSource` is the page the live preview holds.
    case pulse(fingerprint: String, selectedSiteID: String, previewSource: String)
    /// ⌘R: fetch now, then everything. `query` is the search field's text.
    case refresh(selectedSiteID: String, previewSource: String, query: String)
    /// A row was selected (the detail pane is already filled from the row). `previewSource` is the page the live
    /// preview holds; it is swapped only when the site's page differs, so a list update doesn't reload it.
    case selected(siteID: String, previewSource: String)
    /// Typing stopped in the search field: the selected row after filtering (empty when nothing is selected) and
    /// the search text.
    case filtered(selectedSiteID: String, query: String)
    /// ↩, ⌘↩, ⌥↩: finish with this `FinishArgument`, or do nothing when it is empty (no rows).
    case finish(argument: String)
    /// Sign in (or Try again): start a browser sign-in and show its progress.
    case signIn
    /// Cancel while connecting: stop waiting for the browser.
    case cancelSignIn
    /// Retry after a failed first fetch: start a refresh and show "Loading…".
    case retry
    /// The row menu's Sign out: forget the token and the account, and show the signed-out window.
    case signOut

    /// The arguments for `scripts/ui`.
    public var arguments: [String] {
        switch self {
        case .load(let query): ["load", query]
        case .pulse(let fingerprint, let selected, let preview): ["pulse", fingerprint, selected, preview]
        case .refresh(let selected, let preview, let query): ["refresh", selected, preview, query]
        case .selected(let siteID, let preview): ["selected", siteID, preview]
        case .filtered(let selected, let query): ["filtered", selected, query]
        case .finish(let argument): ["finish", argument]
        case .signIn: ["sign-in"]
        case .cancelSignIn: ["cancel-sign-in"]
        case .retry: ["retry"]
        case .signOut: ["sign-out"]
        }
    }

    /// The command these arguments name. No arguments means `load`; missing ones are empty (Alfred sends an empty
    /// string for an unresolved placeholder anyway). Arguments came through `SafeText`, so they are restored.
    public init?(arguments: [String]) {
        let arguments = arguments.map(SafeText.restore)
        func argument(_ index: Int) -> String { index < arguments.count ? arguments[index] : "" }
        switch arguments.first ?? "load" {
        case "load": self = .load(query: argument(1))
        case "pulse": self = .pulse(fingerprint: argument(1), selectedSiteID: argument(2), previewSource: argument(3))
        case "refresh": self = .refresh(selectedSiteID: argument(1), previewSource: argument(2), query: argument(3))
        case "selected": self = .selected(siteID: argument(1), previewSource: argument(2))
        case "filtered": self = .filtered(selectedSiteID: argument(1), query: argument(2))
        case "finish": self = .finish(argument: argument(1))
        case "sign-in": self = .signIn
        case "cancel-sign-in": self = .cancelSignIn
        case "retry": self = .retry
        case "sign-out": self = .signOut
        default: return nil
        }
    }
}
