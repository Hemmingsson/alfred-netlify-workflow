import Foundation
@testable import NetlifyPictures
import Testing

@Suite("Favicon candidates")
struct FaviconCandidatesTests {
    let site = URL(string: "https://example.com/start/")!

    @Test func declaredIconsComeBeforeTouchIconsAndWellKnownAddresses() {
        let html = """
            <link rel="apple-touch-icon" href="/touch.png">
            <link rel="icon" href="data:image/png;base64,AAAA">
            <LINK REL="shortcut icon" HREF='icons/fav.png?a=1&amp;b=2'>
            <link href="/plain.svg" rel="icon" type="image/svg+xml">
            """
        let urls = FaviconCandidates(page: html, at: site).urls.map(\.absoluteString)
        #expect(urls == [
            "https://example.com/start/icons/fav.png?a=1&b=2",
            "https://example.com/plain.svg",
            "https://example.com/touch.png",
            "https://example.com/favicon.ico",
            "https://example.com/apple-touch-icon.png",
        ])
    }

    @Test func aPageWithoutIconsFallsBackToWellKnownAddresses() {
        let urls = FaviconCandidates(page: "", at: site).urls.map(\.absoluteString)
        #expect(urls == ["https://example.com/favicon.ico", "https://example.com/apple-touch-icon.png"])
    }

    @Test func otherLinksAreIgnored() {
        let html = #"<link rel="stylesheet" href="/a.css"><link rel="preload icon-ish" href="/b.png">"#
        #expect(FaviconCandidates(page: html, at: site).urls.count == 2)
    }
}
