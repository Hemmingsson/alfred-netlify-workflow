import Foundation
import NetlifyCore

/// A made-up demo site, described by what shows in its row and detail pane.
struct InventedSite {
    /// An unpublished failed deploy, shown alongside the live site.
    struct FailedDeploy {
        var hoursAgo: Double
        var message: String
    }

    var picture: String
    /// A `*.netlify.app` domain means the site has no custom domain.
    var domain: String
    /// The GitHub repository's name; empty means deployed with the Netlify CLI.
    var repo: String
    var hoursAgo: Double
    var commit = ""
    var committer = ""
    var framework = ""
    var functions = 0
    var newest: FailedDeploy?
    var isLocked = false

    func site(index: Int, now: Date) -> Site {
        func hoursBefore(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }
        let name = String(domain.prefix { $0 != "." })
        let number = String(format: "%02d", index)
        let netlifyDomain = "\(name).netlify.app"
        let hasRepo = !repo.isEmpty
        let published = hoursBefore(hoursAgo)
        let deploy = Deploy(
            id: "deploy-\(number)",
            state: "ready",
            branch: hasRepo ? "main" : nil,
            commitRef: hasRepo ? commitRef(index: index) : nil,
            committer: committer.nonEmpty,
            title: commit.nonEmpty,
            source: hasRepo ? "github" : "cli",
            createdAt: published.addingTimeInterval(-60),
            publishedAt: published,
            framework: framework.nonEmpty,
            functionCount: functions,
            isLocked: isLocked
        )
        return Site(
            id: "demo-\(number)-\(picture)",
            name: name,
            url: URL(string: "https://\(domain)"),
            customDomain: domain == netlifyDomain ? nil : domain,
            netlifyDomain: netlifyDomain,
            adminURL: URL(string: "https://app.netlify.com/projects/\(name)"),
            createdAt: hoursBefore(hoursAgo + 24 * 60),
            updatedAt: max(published, newest.map { hoursBefore($0.hoursAgo) } ?? published),
            repository: hasRepo
                ? Repository(url: URL(string: "https://github.com/example/\(repo)")!, provider: "github")
                : nil,
            publishedDeploy: deploy,
            newestDeploy: newest.map { newestDeploy($0, of: deploy, createdAt: hoursBefore($0.hoursAgo)) }
        )
    }

    /// A stable, made-up 7-character commit hash.
    private func commitRef(index: Int) -> String {
        String(format: "%07x", (index + 7) * 2_654_435_761 & 0xFFF_FFFF)
    }

    private func newestDeploy(_ newest: FailedDeploy, of published: Deploy, createdAt: Date) -> Deploy {
        var deploy = published
        deploy.id = "newer"
        deploy.createdAt = createdAt
        deploy.publishedAt = nil
        deploy.state = "error"
        deploy.errorMessage = newest.message
        return deploy
    }
}
