import AppKit
import CoreGraphics
import Foundation
import WebKit

/// Renders a web page to a PNG with WKWebView, the way a browser window at desktop size would show its top.
///
/// What it takes to get a capture that looks right:
/// - WebKit only lays out and paints inside a window, and throttles timers, animation and WebGL in windows it thinks
///   are hidden. So the page goes in a borderless window that is on screen but fully transparent and click-through,
///   and `inactiveSchedulingPolicy` is `.none`. The process is an accessory-less app (`.prohibited`): no Dock icon,
///   no menu bar, no focus taken.
/// - Some pages never finish loading (streaming video, long polling). Those are captured `settle` after they commit,
///   once the document is interactive; everything is captured at `timeout` with whatever has painted.
/// - Slow pages (WebGL, web fonts, big images) keep painting after `load`, hence the `delay`.
/// - The capture is drawn into a bitmap of exactly `width`×`height` pixels, whatever the screen's backing scale.
///
/// WebKit needs the main run loop: the process must run it (an `async` main does, through CFRunLoopRun).
@MainActor
enum PageRenderer {
    static let width = 1440
    static let height = 900
    /// How long to let a loaded page keep painting.
    static let delay: Duration = .seconds(6)
    /// How long after commit a page that never finishes loading is captured anyway, once interactive.
    static let settle: Duration = .seconds(10)
    /// The hard limit: capture whatever has painted.
    static let timeout: Duration = .seconds(30)

    /// Load `url` and write the capture to `file` as a PNG, atomically. Capture after load plus `delay`, or after
    /// `settle` from commit when the load never finishes, or at `timeout` with whatever has painted. Throws when the
    /// page fails to load, nothing was ever shown, or the capture can't be written.
    static func render(_ url: URL, to file: URL) async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let page = RenderPage(width: width, height: height)
        defer { page.close() }
        page.load(url, timeout: timeout)
        try await waitUntilPainted(page)
        let image = try await page.capture()
        try image.writePNG(to: file)
    }

    /// Returns once the page is worth capturing; see `render`.
    private static func waitUntilPainted(_ page: RenderPage) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if let failure = page.failure { throw failure }
            if let finished = page.finishedAt, clock.now >= finished + delay { return }
            if let committed = page.committedAt, page.finishedAt == nil, clock.now >= committed + settle,
               await page.isInteractive() {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard page.committedAt != nil else { throw PictureError.timedOut }
    }
}
