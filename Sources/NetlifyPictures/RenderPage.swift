import AppKit
import WebKit

/// One page being rendered: a WKWebView in an invisible on-screen window, and what its navigation has done so far.
@MainActor
final class RenderPage: NSObject, WKNavigationDelegate {
    /// When the main frame's content started arriving.
    private(set) var committedAt: ContinuousClock.Instant?
    /// When the page's `load` event fired.
    private(set) var finishedAt: ContinuousClock.Instant?
    /// Why the page failed to load, if it did.
    private(set) var failure: PictureError?

    private let size: CGSize
    private let window: NSWindow
    private let webView: WKWebView

    /// Hides scroll bars and starts at the top, so the capture looks like the top of a browser window.
    private static let tidyScript = WKUserScript(
        source: """
            const style = document.createElement('style');
            style.textContent = '::-webkit-scrollbar { display: none !important; }';
            document.documentElement.appendChild(style);
            window.scrollTo(0, 0);
            """,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: true
    )

    init(width: Int, height: Int) {
        size = CGSize(width: width, height: height)
        let frame = CGRect(origin: .zero, size: size)

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.preferences.inactiveSchedulingPolicy = .none
        configuration.userContentController.addUserScript(Self.tidyScript)
        webView = WKWebView(frame: frame, configuration: configuration)

        window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        window.contentView = webView
        super.init()
        webView.navigationDelegate = self
        window.orderFrontRegardless()
    }

    func load(_ url: URL, timeout: Duration) {
        let seconds = Double(timeout.components.seconds)
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: seconds))
    }

    /// True once the document is past `loading` (its DOM is parsed and it is painting).
    func isInteractive() async -> Bool {
        let state = try? await webView.evaluateJavaScript("document.readyState") as? String
        return state.map { $0 != "loading" } ?? false
    }

    /// What has painted so far, as exactly `size` pixels.
    func capture() async throws -> CGImage {
        _ = try? await webView.evaluateJavaScript("window.scrollTo(0, 0)")
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(origin: .zero, size: size)
        configuration.afterScreenUpdates = true
        let snapshot = try await webView.takeSnapshot(configuration: configuration)
        var rect = CGRect(origin: .zero, size: snapshot.size)
        guard let image = snapshot.cgImage(forProposedRect: &rect, context: nil, hints: nil)?
            .croppedToCover(width: Int(size.width), height: Int(size.height))
        else { throw PictureError.noSnapshot }
        return image
    }

    func close() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        window.orderOut(nil)
        window.close()
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        committedAt = .now
        finishedAt = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishedAt = .now
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        recordFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        recordFailure(error)
    }

    /// A cancelled navigation (a redirect replacing it, a download) isn't a failure of the page.
    private func recordFailure(_ error: any Error) {
        let error = error as NSError
        if error.domain == NSURLErrorDomain, error.code == NSURLErrorCancelled { return }
        failure = .pageDidNotLoad(error.localizedDescription)
    }
}
