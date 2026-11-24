import CoreGraphics
import Foundation
import NetlifyCore

/// The network side of the picture jobs: screenshots, favicons and framing checks, through `HTTPClient`.
struct PictureDownloader: Sendable {
    /// Some sites turn away clients that don't look like a browser.
    static let browserUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    let http: any HTTPClient

    /// Netlify's screenshot (often WebP), decoded.
    func screenshot(from url: URL) async throws -> CGImage {
        let response = try await get(url, byteLimit: 10_000_000, asBrowser: false)
        guard response.isSuccess else { throw PictureError.httpStatus(response.status) }
        guard let image = CGImage.decoded(from: response.body) else { throw PictureError.notAnImage }
        return image
    }

    /// The site's favicon as fetched: the first candidate from `FaviconCandidates` that `accept` takes. Reading the
    /// home page may fail; the well-known addresses are still tried.
    func favicon(of site: URL, accept: (Data) throws -> Void) async throws {
        let page = try? await get(site, byteLimit: 100_000, asBrowser: true)
        let html = page.map { String(decoding: $0.body, as: UTF8.self) } ?? ""
        var lastProblem: any Error = PictureError.notAnImage
        for candidate in FaviconCandidates(page: html, at: site).urls {
            do {
                let response = try await get(candidate, byteLimit: 2_000_000, asBrowser: true)
                guard response.isSuccess else { throw PictureError.httpStatus(response.status) }
                try accept(response.body)
                return
            } catch {
                lastProblem = error
            }
        }
        throw lastProblem
    }

    /// May the site be framed? A site that can't be reached (timeout, bad certificate) counts as refusing, since the
    /// iframe wouldn't show it either; so this check never skips certificate checks.
    func framingCheck(of site: URL) async -> FramingCheck {
        let request = HTTPRequest(.get, site, headers: ["User-Agent": Self.browserUserAgent, "Accept": "text/html"], timeout: 10, byteLimit: 1024)
        do {
            return FramingCheck(headersOf: try await http.send(request))
        } catch {
            return .refused("unreachable: \(error.localizedDescription)")
        }
    }

    /// GET, retried without certificate checks when TLS fails: a few custom domains serve a certificate for another
    /// host name, and a picture from them is harmless.
    private func get(_ url: URL, byteLimit: Int, asBrowser: Bool) async throws -> HTTPResponse {
        let headers = asBrowser ? ["User-Agent": Self.browserUserAgent] : [:]
        let request = HTTPRequest(.get, url, headers: headers, timeout: 20, byteLimit: byteLimit)
        do {
            return try await http.send(request)
        } catch let error as URLError where Self.certificateProblems.contains(error.code) {
            var retry = request
            retry.acceptsAnyCertificate = true
            return try await http.send(retry)
        }
    }

    private static let certificateProblems: Set<URLError.Code> = [
        .secureConnectionFailed,
        .serverCertificateHasBadDate,
        .serverCertificateUntrusted,
        .serverCertificateHasUnknownRoot,
        .serverCertificateNotYetValid,
    ]
}
