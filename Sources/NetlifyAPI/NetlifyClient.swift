import Foundation
import NetlifyCore

/// Talks to the Netlify API (`https://api.netlify.com/api/v1`) with the saved token. Turns Netlify's JSON into
/// `Site` and `Deploy` through its own response types. Throws `NetlifyError`: `.signedOut` without a token,
/// `.signInRejected` when Netlify answers 401.
public struct NetlifyClient: Sendable {
    /// Netlify's largest page of sites.
    static let sitesPerPage = 100

    let context: Context

    public init(context: Context) {
        self.context = context
    }

    private var api: APIConnection { APIConnection(http: context.http) }

    /// Every site of the account, across all teams: all pages, following `Link: rel="next"`, unsorted.
    public func sites() async throws -> [Site] {
        let token = try savedToken()
        var next: URL? = APIConnection.url("sites", query: ["filter": "all", "per_page": String(Self.sitesPerPage)])
        var visited: Set<URL> = []
        var sites: [Site] = []
        // The token only goes to the API's own host, and a page is never fetched twice.
        while let page = next, APIConnection.isAPIAddress(page), visited.insert(page).inserted {
            let response = try await api.send(.get, page, token: token)
            let body: [SiteResponse] = try api.decode(response)
            sites += body.map(\.site)
            next = response.nextPageURL
        }
        return sites
    }

    /// The newest production deploy of a site, or nil when it has none.
    public func newestProductionDeploy(siteID: String) async throws -> Deploy? {
        let url = APIConnection.url("sites", siteID, "deploys", query: ["per_page": "1", "production": "true"])
        let body: [DeployResponse] = try await api.get(url, token: try savedToken())
        return body.first?.deploy
    }

    /// Form and submission counts of a site.
    public func forms(siteID: String) async throws -> Site.Forms {
        let body: [FormResponse] = try await api.get(APIConnection.url("sites", siteID, "forms"), token: try savedToken())
        return Site.Forms(count: body.count, submissions: body.reduce(0) { $0 + ($1.submissionCount ?? 0) })
    }

    private func savedToken() throws -> String {
        guard let token = try context.tokens.read() else { throw NetlifyError.signedOut }
        return token
    }
}

/// One form of a site (`GET /sites/{id}/forms`).
private struct FormResponse: Decodable {
    var submissionCount: Int?

    enum CodingKeys: String, CodingKey {
        case submissionCount = "submission_count"
    }
}

private extension HTTPResponse {
    /// The next page of a paginated list: the `rel="next"` address in the `Link` header.
    var nextPageURL: URL? {
        guard let link = header("Link"),
              let match = link.firstMatch(of: #/<([^>]+)>\s*;\s*rel="next"/#)
        else { return nil }
        return URL(string: String(match.1))
    }
}
