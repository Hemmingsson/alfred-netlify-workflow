import Foundation
import NetlifyCore

/// Synthetic deploy metadata for a preview with a chosen demo address.
struct InventedSite {
    var picture: String
    /// A `*.netlify.app` domain means the site has no custom domain.
    var domain: String
    /// The GitHub repository's name; empty means deployed with the Netlify CLI.
    var repo: String
    var hoursAgo: Double
    var framework = ""
    var functions = 0

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
            source: hasRepo ? "github" : "cli",
            createdAt: published.addingTimeInterval(-60),
            publishedAt: published,
            framework: framework.nonEmpty,
            functionCount: functions
        )
        return Site(
            id: "demo-\(number)-\(picture)",
            name: name,
            url: URL(string: "https://\(domain)"),
            customDomain: domain == netlifyDomain ? nil : domain,
            netlifyDomain: netlifyDomain,
            adminURL: URL(string: "https://app.netlify.com/projects/\(name)"),
            createdAt: hoursBefore(hoursAgo + 24 * 60),
            updatedAt: published,
            repository: hasRepo
                ? Repository(url: URL(string: "https://github.com/example/\(repo)")!, provider: "github")
                : nil,
            publishedDeploy: deploy
        )
    }

    /// A stable, made-up 7-character commit hash.
    private func commitRef(index: Int) -> String {
        String(format: "%07x", (index + 7) * 2_654_435_761 & 0xFFF_FFFF)
    }

}
