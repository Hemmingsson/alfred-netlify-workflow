import AppKit
import Foundation
import NetlifyCore

/// The Mac: NSWorkspace, NSPasteboard, and Alfred's External Trigger `browse` (to reopen the window).
///
/// The trigger goes through `/usr/bin/osascript`: sending Apple Events in-process would need the
/// `automation.apple-events` entitlement under the hardened runtime. Text is passed as `argv`, never spliced into
/// the script. The binary posts no notifications: an osascript notification is shown as coming from Script Editor.
/// Progress and errors show in the window; "Copied <url>" goes through Alfred's Post Notification object.
struct MacSystemActions: SystemActions {
    let bundleID: String

    static let alfredBundleID = "com.runningwithcrayons.Alfred"
    static let reopenTriggerID = "browse"

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func reopenWindow() {
        Self.runAppleScript(Self.reopenScript, arguments: [Self.alfredBundleID, Self.reopenTriggerID, bundleID])
    }

    static let reopenScript = [
        "on run argv",
        "tell application id (item 1 of argv) to run trigger (item 2 of argv) in workflow (item 3 of argv)",
        "end run",
    ]

    /// The `osascript` arguments that run `lines` with `arguments` as its `argv`.
    static func osascriptArguments(_ lines: [String], arguments: [String]) -> [String] {
        lines.flatMap { ["-e", $0] } + arguments
    }

    /// Runs the script and waits; its output is discarded so it never reaches Alfred's pipe.
    private static func runAppleScript(_ lines: [String], arguments: [String]) {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/osascript")
        process.arguments = osascriptArguments(lines, arguments: arguments)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            Log.write("osascript: \(error.localizedDescription)")
        }
    }
}
