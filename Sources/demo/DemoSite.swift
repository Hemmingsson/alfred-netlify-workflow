import Foundation
import NetlifyCore

/// One row of the demo account.
enum DemoSite {
    /// A real site from `demo/real/<name>.json`, published `hoursAgo` hours ago; `customDomain` replaces its own.
    case real(name: String, hoursAgo: Double, customDomain: String? = nil, buildingHoursAgo: Double? = nil)
    /// A display-only preview with synthetic deploy metadata and an approved demo address.
    case invented(InventedSite)

    /// The demo rows, newest first: README screenshots show them in this order with the first one selected.
    static let catalogue: [DemoSite] = [
        .real(name: "blandband", hoursAgo: 3, buildingHoursAgo: 0.05),
        .invented(InventedSite(picture: "streamdeck", domain: "autonomous-streamdeck-icons.mattias.work",
                               repo: "autonomous-streamdeck-icons", hoursAgo: 8)),
        .real(name: "nottoys", hoursAgo: 14),
        .invented(InventedSite(picture: "collage", domain: "depiction.paradisearchitects.com",
                               repo: "depiction", hoursAgo: 20)),
        .invented(InventedSite(picture: "results", domain: "aet-streamdeck-results.mattias.work",
                               repo: "aet-streamdeck-results", hoursAgo: 30)),
        .invented(InventedSite(picture: "dashboard", domain: "einride-dashboard.mattias.work",
                               repo: "einride-dashboard", hoursAgo: 52, framework: "next", functions: 2)),
        .real(name: "sapo", hoursAgo: 100),
        .real(name: "dancemusic", hoursAgo: 130),
        .invented(InventedSite(picture: "mattias", domain: "mattias.stream",
                               repo: "mattias-stream", hoursAgo: 170)),
        .real(name: "electricbeer", hoursAgo: 220, customDomain: "electricbeer.tech"),
    ]

    /// The base name of the files in `demo/pictures` and `demo/favicons`.
    var picture: String {
        switch self {
        case .real(let name, _, _, _): name
        case .invented(let site): site.picture
        }
    }

    /// The site as the cache stores it; `index` keeps invented ids unique.
    func site(index: Int, sources: URL, now: Date) throws -> Site {
        switch self {
        case .real(let name, let hoursAgo, let customDomain, let buildingHoursAgo):
            let file = sources.appending(path: "real/\(name).json")
            let record = try RealSiteRecord.decoder.decode(RealSiteRecord.self, from: Data(contentsOf: file))
            var site = record.site(publishedAt: now.addingTimeInterval(-hoursAgo * 3600), customDomain: customDomain)
            if let buildingHoursAgo, var deploy = site.publishedDeploy {
                deploy.id = "demo-building-" + deploy.id
                deploy.state = "building"
                deploy.createdAt = now.addingTimeInterval(-buildingHoursAgo * 3600)
                deploy.publishedAt = nil
                site.newestDeploy = deploy
                site.updatedAt = deploy.createdAt
            }
            return site
        case .invented(let site):
            return site.site(index: index, now: now)
        }
    }
}
