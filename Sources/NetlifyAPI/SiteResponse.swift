import Foundation
import NetlifyCore

/// A site as Netlify describes it (`GET /sites`).
struct SiteResponse: Decodable {
    var id: String
    var name: String?
    var url: String?
    var sslURL: String?
    var customDomain: String?
    var domainAliases: [String]?
    var defaultDomain: String?
    var adminURL: String?
    var createdAt: Date
    var updatedAt: Date
    var screenshotURL: String?
    var ssl: Bool?
    var hasPassword: Bool?
    var useForms: Bool?
    var buildSettings: BuildSettings?
    var publishedDeploy: DeployResponse?

    /// Where the site builds from; empty for sites deployed by the CLI, the API or drag and drop.
    struct BuildSettings: Decodable {
        var repoURL: String?
        var provider: String?

        enum CodingKeys: String, CodingKey {
            case provider
            case repoURL = "repo_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, url, ssl
        case sslURL = "ssl_url"
        case customDomain = "custom_domain"
        case domainAliases = "domain_aliases"
        case defaultDomain = "default_domain"
        case adminURL = "admin_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case screenshotURL = "screenshot_url"
        case hasPassword = "has_password"
        case useForms = "use_forms"
        case buildSettings = "build_settings"
        case publishedDeploy = "published_deploy"
    }

    var site: Site {
        let name = name ?? ""
        return Site(
            id: id,
            name: name,
            url: (sslURL.nonEmpty ?? url.nonEmpty).flatMap(URL.init(string:)),
            customDomain: customDomain.nonEmpty,
            domainAliases: (domainAliases ?? []).filter { !$0.isEmpty },
            netlifyDomain: defaultDomain.nonEmpty ?? "\(name).netlify.app",
            adminURL: adminURL.nonEmpty.flatMap(URL.init(string:)),
            createdAt: createdAt,
            updatedAt: updatedAt,
            screenshotURL: (screenshotURL.nonEmpty ?? publishedDeploy?.screenshotURL.nonEmpty).flatMap(URL.init(string:)),
            repository: repository,
            hasSSL: ssl ?? false,
            hasPassword: hasPassword ?? false,
            usesForms: useForms ?? false,
            publishedDeploy: publishedDeploy?.deploy
        )
    }

    private var repository: Repository? {
        guard let url = buildSettings?.repoURL.nonEmpty.flatMap(URL.init(string:)) else { return nil }
        return Repository(url: url, provider: buildSettings?.provider.nonEmpty)
    }
}
