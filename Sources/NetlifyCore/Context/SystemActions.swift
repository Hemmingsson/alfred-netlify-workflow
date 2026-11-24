import Foundation

/// What the app does to the Mac outside the window. Live in NetlifyCLI; tests record the calls.
public protocol SystemActions: Sendable {
    /// Open in the default browser (or app).
    func open(_ url: URL)
    func copy(_ text: String)
    /// Open the site browser window again (Alfred's External Trigger), e.g. after signing in.
    func reopenWindow()
}
