import Foundation
import NetlifyCore

/// The facts about a site that rows, the detail pane and the row menu word the same way.
struct SiteSummary: Sendable {
    let site: Site

    init(_ site: Site) {
        self.site = site
    }

    /// The custom domain, else the host of the site URL, else the `*.netlify.app` domain; punycode shown as Unicode.
    var host: String {
        let host = site.customDomain.nonEmpty ?? site.url?.host() ?? site.netlifyDomain
        return Punycode.displayHost(host)
    }

    /// The repository's name, when there is a linked one.
    var repositoryName: String? {
        site.repository?.name.nonEmpty
    }

    /// Where Open Site goes.
    var siteURL: URL {
        site.url ?? URL(string: "https://\(site.netlifyDomain)")!
    }

    /// The site URL as the address bar shows it, its host in Unicode.
    var displayURL: String {
        let text = siteURL.absoluteString
        guard let host = siteURL.host(), host.lowercased().contains("xn--") else { return text }
        return text.replacingOccurrences(of: host, with: Punycode.displayHost(host))
    }

    /// The project in Netlify's dashboard: the API's admin URL, else `app.netlify.com/projects/<name>`.
    var adminURL: URL {
        site.adminURL ?? URL(string: "https://app.netlify.com/projects")!.appending(path: site.name)
    }

    var deploysURL: URL { adminURL.appending(path: "deploys") }

    /// What search matches: the names, plus their pieces split on `. - _ / :`, without the noise pieces.
    var searchText: String {
        let names = [site.name, host, repositoryName, site.netlifyDomain, Punycode.displayHost(site.netlifyDomain)]
            + site.domainAliases + site.domainAliases.map(Punycode.displayHost)
        var words: [String] = []
        for name in names.compactMap({ $0 }) where !name.isEmpty {
            words.append(name)
            words += name.split(whereSeparator: { ".-_/:".contains($0) }).map(String.init)
                .filter { !Self.noise.contains($0.lowercased()) }
        }
        var seen = Set<String>()
        return words.filter { seen.insert($0).inserted }.joined(separator: " ")
    }

    private static let noise: Set<String> = ["netlify", "app", "www", "com"]

    /// A deploy's title: its commit message's first line, else how it was deployed.
    static func title(of deploy: Deploy) -> String {
        TextFormatter.firstLine(deploy.title) ?? sourceText(deploy.source) ?? "Manual deploy"
    }

    /// "Deployed with the Netlify CLI", "Deployed through the API", or nil for other sources.
    static func sourceText(_ source: String?) -> String? {
        switch source {
        case "cli": "Deployed with the Netlify CLI"
        case "api": "Deployed through the API"
        default: nil
        }
    }
}
