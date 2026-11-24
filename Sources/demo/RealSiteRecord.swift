import Foundation
import NetlifyCore

/// A real site as saved in `demo/real/*.json` (snake_case keys, empty strings for missing values).
struct RealSiteRecord: Decodable {
    var id: String
    var name: String
    var url: String
    var customDomain: String
    var domainAliases: [String]
    var defaultDomain: String
    var adminUrl: String
    var createdAt: Date
    var publishedAt: Date
    var screenshotUrl: String
    var repoUrl: String
    var provider: String
    var ssl: Bool
    var hasPassword: Bool
    var useForms: Bool
    var deploy: DeployRecord

    /// The published deploy.
    struct DeployRecord: Decodable {
        var id: String
        var state: String
        var branch: String
        var commitRef: String
        var committer: String
        var title: String
        var source: String
        var createdAt: Date
        var error: String
        var framework: String
        var functions: Int
        var schedules: Int
        var edge: Bool
        var locked: Bool
    }

    /// Reads the snake_case keys.
    static var decoder: JSONDecoder {
        let decoder = JSON.decoder
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// The site, as if it had been published at `publishedAt` (the deploy keeps its real build time).
    func site(publishedAt: Date, customDomain override: String?) -> Site {
        let buildTime = self.publishedAt.timeIntervalSince(deploy.createdAt)
        let customDomain = override ?? customDomain.nonEmpty
        let published = Deploy(
            id: deploy.id,
            state: deploy.state,
            branch: deploy.branch.nonEmpty,
            commitRef: deploy.commitRef.nonEmpty,
            committer: deploy.committer.nonEmpty,
            title: deploy.title.nonEmpty,
            source: deploy.source.nonEmpty,
            createdAt: publishedAt.addingTimeInterval(-buildTime),
            publishedAt: publishedAt,
            errorMessage: deploy.error.nonEmpty,
            framework: deploy.framework.nonEmpty,
            functionCount: deploy.functions,
            scheduledFunctionCount: deploy.schedules,
            hasEdgeFunctions: deploy.edge,
            isLocked: deploy.locked
        )
        return Site(
            id: id,
            name: name,
            url: URL(string: override.map { "https://\($0)" } ?? url),
            customDomain: customDomain,
            domainAliases: domainAliases,
            netlifyDomain: defaultDomain,
            adminURL: URL(string: adminUrl),
            createdAt: createdAt,
            updatedAt: publishedAt,
            screenshotURL: URL(string: screenshotUrl),
            repository: URL(string: repoUrl).map { Repository(url: $0, provider: provider.nonEmpty) },
            hasSSL: ssl,
            hasPassword: hasPassword,
            usesForms: useForms,
            publishedDeploy: published
        )
    }
}
