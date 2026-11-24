import NetlifyCore

/// One extra request a refresh makes about a site, beyond the site list.
enum SiteLookup: Sendable {
    /// The newest production deploy, which may be building or have failed.
    case newestDeploy(siteID: String)
    /// Form and submission counts.
    case forms(siteID: String)

    /// What a lookup found, as a change to its site.
    typealias Update = @Sendable (inout Site) -> Void

    var siteID: String {
        switch self {
        case .newestDeploy(let siteID), .forms(let siteID): siteID
        }
    }

    /// Ask Netlify.
    func run(with client: NetlifyClient) async throws -> Update {
        switch self {
        case .newestDeploy(let siteID):
            let deploy = try await client.newestProductionDeploy(siteID: siteID)
            return { $0.newestDeploy = deploy }
        case .forms(let siteID):
            let forms = try await client.forms(siteID: siteID)
            return { $0.forms = forms }
        }
    }
}
