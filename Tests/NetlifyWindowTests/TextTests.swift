import Foundation
import NetlifyTesting
import Testing
@testable import NetlifyWindow

@Suite("Words for times, counts and domains")
struct TextTests {
    let text = TextFormatter(now: Fixtures.now, timeZone: TimeZone(identifier: "Europe/Stockholm")!)

    @Test(arguments: [
        (30.0, "just now"), (4 * 60, "4 min ago"), (75 * 60, "1 h ago"), (3 * 3600 + 59, "3 h ago"),
        (12 * 86400, "12 d ago"), (44 * 86400, "44 d ago"), (60 * 86400, "2 mo ago"), (400 * 86400, "1 y ago"),
    ] as [(Double, String)])
    func ages(seconds: Double, expected: String) {
        #expect(text.ago(Fixtures.now - seconds) == expected)
    }

    @Test func aFutureDateIsJustNow() {
        #expect(text.ago(Fixtures.now + 120) == "just now")
    }

    @Test func longDatesUseLocalTimeAndAddOtherYears() {
        #expect(text.longDate(Fixtures.date("2026-11-18T16:00:00Z")) == "Nov 18 at 17:00")
        #expect(text.longDate(Fixtures.date("2025-03-02T08:05:00Z")) == "Mar 2, 2025 at 09:05")
    }

    @Test func plurals() {
        #expect(TextFormatter.plural(1, "site") == "1 site")
        #expect(TextFormatter.plural(0, "site") == "0 sites")
        #expect(TextFormatter.plural(3, "form") == "3 forms")
    }

    @Test func firstLines() {
        #expect(TextFormatter.firstLine("\n  Merge branch  \n\nmore") == "Merge branch")
        #expect(TextFormatter.firstLine("   ") == nil)
        #expect(TextFormatter.firstLine(nil) == nil)
    }

    @Test(arguments: [
        ("xn--spo-qla.com", "säpo.com"), ("www.xn--bcher-kva.example", "www.bücher.example"),
        ("xn--mnchen-3ya.de", "münchen.de"), ("plain.example", "plain.example"), ("xn--!!.com", "xn--!!.com"),
        ("xn--uv767205604493046e.com", "xn--uv767205604493046e.com"),
    ] as [(String, String)])
    func punycodeHostsShowInUnicode(host: String, shown: String) {
        #expect(Punycode.displayHost(host) == shown)
    }
}
