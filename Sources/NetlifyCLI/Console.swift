import Foundation
import NetlifyCore

/// Where a command writes: stdout, which Alfred reads (the window's JSON, or an action's text for the Post
/// Notification object), and diagnostics (`Log`). Tests capture both.
struct Console: Sendable {
    /// Writes to stdout.
    var output: @Sendable (Data) -> Void
    /// Writes one diagnostic line to stderr.
    var diagnostic: @Sendable (String) -> Void

    /// The process's own stdout and stderr.
    static let standard = Console(
        output: { FileHandle.standardOutput.write($0) },
        diagnostic: { Log.write($0) }
    )
}
