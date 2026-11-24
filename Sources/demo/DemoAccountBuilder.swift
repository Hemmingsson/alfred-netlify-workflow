import Foundation
import NetlifyCore
import NetlifyPictures

/// Writes a demo account folder: the sites of `catalogue` in `SiteCache`, with times relative to `now`, and their
/// pictures and favicons adopted as if they had been fetched. Nothing touches the network.
struct DemoAccountBuilder {
    /// The repository's `demo/` folder: `real/*.json`, `pictures/*.jpg`, `favicons/*`.
    let sources: URL
    /// The workflow folder (the fallback icon).
    let workflowFolder: URL
    let now: Date
    /// The picture store to adopt pictures into, for the demo folder's context.
    let makePictures: (Context) -> any DemoPictures
    var catalogue: [DemoSite] = DemoSite.catalogue

    /// Replaces `folder` with a fresh demo account and returns its sites, newest first.
    @discardableResult
    func build(into folder: URL) throws -> [Site] {
        try clear(folder)
        let scratch = FileManager.default.temporaryDirectory.appending(path: "netlify-demo-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let paths = Paths(cacheFolder: scratch, workflowFolder: workflowFolder, demoFolder: folder)
        let now = self.now
        let context = Context(
            settings: Settings(demoFolder: folder),
            paths: paths,
            http: Offline(),
            tokens: Offline(),
            jobs: Offline(),
            system: Offline(),
            now: { now }
        )
        let sites = try catalogue.enumerated().map { index, entry in
            try entry.site(index: index, sources: sources, now: now)
        }
        try SiteCache(paths: paths).write(sites, savedAt: now)

        let pictures = makePictures(context)
        for (entry, site) in zip(catalogue, sites) {
            try pictures.adoptDemoPictures(screenshot: try screenshot(of: entry), favicon: favicon(of: entry), for: site)
        }
        return sites
    }

    /// The picture that stands in for Netlify's screenshot of the site.
    func screenshot(of entry: DemoSite) throws -> URL {
        let file = sources.appending(path: "pictures/\(entry.picture).jpg")
        guard FileManager.default.fileExists(atPath: file.path) else { throw DemoBuildError.missingPicture(file) }
        return file
    }

    /// `favicons/<picture>.<any extension>`, when there is one.
    func favicon(of entry: DemoSite) -> URL? {
        let folder = sources.appending(path: "favicons", directoryHint: .isDirectory)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.sorted()
            .first { ($0 as NSString).deletingPathExtension == entry.picture }
            .map { folder.appending(path: $0) }
    }

    /// Deletes an earlier demo folder at `folder`. Refuses a folder that has other things in it, so a typo can't
    /// wipe a folder that isn't a demo.
    private func clear(_ folder: URL) throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: folder.path) else { return }
        let contents = try manager.contentsOfDirectory(atPath: folder.path).filter { $0 != ".DS_Store" }
        let isDemo = contents.isEmpty || contents.contains("sites.json")
        guard isDemo else { throw DemoBuildError.notADemoFolder(folder) }
        try manager.removeItem(at: folder)
    }
}

/// Why the demo folder couldn't be built.
enum DemoBuildError: Error, Equatable, LocalizedError {
    /// The folder exists with files in it that aren't an earlier demo.
    case notADemoFolder(URL)
    case missingPicture(URL)

    var errorDescription: String? {
        switch self {
        case .notADemoFolder(let url): "\(url.path) is not empty and not a demo folder; not replacing it."
        case .missingPicture(let url): "missing demo picture \(url.path)"
        }
    }
}

/// Where the demo tool puts ready-made pictures: `PictureStore`, or a recorder in tests.
protocol DemoPictures {
    func adoptDemoPictures(screenshot: URL?, favicon: URL?, for site: Site) throws
}

extension PictureStore: DemoPictures {}
