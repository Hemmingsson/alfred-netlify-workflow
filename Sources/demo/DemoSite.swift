import Foundation
import NetlifyCore

/// One row of the demo account.
enum DemoSite {
    /// A real site from `demo/real/<name>.json`, published `hoursAgo` hours ago; `customDomain` replaces its own.
    case real(name: String, hoursAgo: Double, customDomain: String? = nil, buildingHoursAgo: Double? = nil)
    /// A made-up site: every name, domain, repo, commit and deploy state is invented.
    case invented(InventedSite)

    /// The demo rows, newest first: README screenshots show them in this order with the first one selected.
    static let catalogue: [DemoSite] = [
        .real(name: "blandband", hoursAgo: 3, buildingHoursAgo: 0.05),
        .real(name: "nottoys", hoursAgo: 8),
        .invented(InventedSite(picture: "collage", domain: "atlas-of-eden.org", repo: "atlas-of-eden", hoursAgo: 20,
                               commit: "Add forty new paintings to the gallery", committer: "Ines Holm")),
        .invented(InventedSite(picture: "padgrid", domain: "padgrid.app", repo: "padgrid", hoursAgo: 30,
                               commit: "Tune the colour ramp for velocity", committer: "Jonas Berg", framework: "svelte-kit",
                               functions: 1)),
        .invented(InventedSite(picture: "dashboard", domain: "einride-dashboard.netlify.app", repo: "einride-dashboard", hoursAgo: 52,
                               commit: "Show charging sessions per week", committer: "Mira Lund", framework: "next", functions: 2)),
        .real(name: "electricbeer", hoursAgo: 75, customDomain: "electricbeer.tech"),
        .real(name: "sapo", hoursAgo: 100),
        .real(name: "dancemusic", hoursAgo: 130),
        .invented(InventedSite(picture: "magazine", domain: "harbourmag.com", repo: "harbour-magazine", hoursAgo: 170,
                               commit: "Spring issue: boats of the year", committer: "Jonas Berg", framework: "astro", isLocked: true)),
        .invented(InventedSite(picture: "edm", domain: "groovebox.wtf", repo: "groovebox", hoursAgo: 220,
                               commit: "Four pads, one loop", committer: "Ines Holm", framework: "svelte-kit")),
        .invented(InventedSite(picture: "switches", domain: "switchboard.tools", repo: "switchboard", hoursAgo: 300,
                               commit: "New gear and drive icons", committer: "Jonas Berg", framework: "svelte-kit", functions: 1,
                               newest: .init(hoursAgo: 20, message: "Build script returned non-zero exit code: 2"))),
        .invented(InventedSite(picture: "bluescreen", domain: "bluescreen.club", repo: "bluescreen", hoursAgo: 700,
                               commit: "A corner of the web, in blue", committer: "Jonas Berg")),
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
