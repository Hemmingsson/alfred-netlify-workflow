import Foundation
import NetlifyCore

/// Sample data for tests: a site as Netlify would describe it.
public enum Fixtures {
    /// "Now" in tests: 2026-11-20 12:00 UTC.
    public static let now = date("2026-11-20T12:00:00Z")

    /// An ISO 8601 date; crashes on a typo, which in a fixture is what we want.
    public static func date(_ iso: String) -> Date {
        try! Date(iso, strategy: .iso8601)
    }

    /// A published production deploy from GitHub.
    public static func deploy(id: String = "d1", state: String = "ready", createdAt: String = "2026-11-18T16:00:00Z") -> Deploy {
        Deploy(
            id: id,
            state: state,
            branch: "main",
            commitRef: "0d591148aa",
            committer: "Hemmingsson",
            title: "Merge remote-tracking branch 'origin/canvas-perf'\n\nmore",
            source: "github",
            createdAt: date(createdAt),
            publishedAt: state == "ready" ? date(createdAt) : nil,
            framework: "svelte-kit",
            functionCount: 1
        )
    }

    /// A site with a custom domain, a GitHub repository and a published deploy.
    public static func site(id: String = "s1") -> Site {
        Site(
            id: id,
            name: "dulcet-paletas-403ab7",
            url: URL(string: "https://streamdeck-canvas.example"),
            customDomain: "streamdeck-canvas.example",
            netlifyDomain: "dulcet-paletas-403ab7.netlify.app",
            adminURL: URL(string: "https://app.netlify.com/projects/dulcet-paletas-403ab7"),
            createdAt: date("2026-11-18T10:00:00Z"),
            updatedAt: date("2026-11-18T16:00:00Z"),
            screenshotURL: URL(string: "https://d33wubrfki0l68.cloudfront.net/screenshot.png"),
            repository: Repository(url: URL(string: "https://github.com/example/einride-ro-streamdeck")!, provider: "github"),
            publishedDeploy: deploy()
        )
    }
}
