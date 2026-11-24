import NetlifyCore
@testable import NetlifyPictures
import Testing

@Suite("Framing check")
struct FramingCheckTests {
    func check(_ headers: [String: String], status: Int = 200) -> FramingCheck {
        FramingCheck(headersOf: HTTPResponse(status: status, headers: headers))
    }

    @Test(arguments: ["DENY", "sameorigin", "ALLOW-FROM https://a.example"])
    func xFrameOptionsRefuse(_ value: String) {
        #expect(!check(["X-Frame-Options": value]).allowsFraming)
    }

    @Test func frameAncestorsWithoutStarRefuse() {
        #expect(!check(["Content-Security-Policy": "default-src 'self'; frame-ancestors 'self' https://a.example"]).allowsFraming)
        #expect(!check(["content-security-policy": "frame-ancestors 'none'"]).allowsFraming)
    }

    @Test func frameAncestorsStarAllows() {
        #expect(check(["Content-Security-Policy": "frame-ancestors *; img-src *"]).allowsFraming)
    }

    @Test func noHeadersAllow() {
        #expect(check([:]) == .allowed)
        #expect(check(["Content-Security-Policy": "default-src 'self'"]).allowsFraming)
    }

    @Test func anErrorPageIsJudgedByItsHeaders() {
        #expect(check([:], status: 404).allowsFraming)
        #expect(!check(["X-Frame-Options": "DENY"], status: 500).allowsFraming)
    }
}
