import Foundation
import NetlifyCore

/// The background jobs that make pictures: `pictures` (screenshots, favicons, framing checks, thumbnails and the
/// tidy; only the network) and `render <site id>` (our own capture of a selected site, with WebKit).
public struct PictureJobs: Sendable {
    /// Downloads and checks running at once.
    static let downloadLimit = 8

    let context: Context
    /// Renders a page to a PNG file; WebKit in the app, a stand-in in tests.
    let renderPage: @Sendable (URL, URL) async throws -> Void

    public init(context: Context) {
        self.init(context: context) { url, file in
            try await PageRenderer.render(url, to: file)
        }
    }

    init(context: Context, renderPage: @escaping @Sendable (URL, URL) async throws -> Void) {
        self.context = context
        self.renderPage = renderPage
    }

    /// The `pictures` job, holding its lock: for each published site, Netlify's screenshot, the favicon, the framing
    /// check and the thumbnail, at most 8 sites at a time; then delete pictures nothing uses any more. A failed
    /// download is tried again after 24 hours.
    public func fetchMissing() async {
        guard !context.settings.isDemo, let session = try? AccountSession(paths: context.paths) else { return }
        await JobLock(.pictures, paths: context.paths, session: session).tryHolding {
            guard let sites = SiteCache(paths: context.paths).read()?.sites else { return }
            let downloader = PictureDownloader(http: context.http)
            let folder = context.paths.picturesFolder
            await sites.compactMap { DeployPictures($0, in: folder) }.concurrentMap(limit: Self.downloadLimit) { pictures in
                await fetchMissing(for: pictures, with: downloader, session: session)
            }
            // A refresh may have finished meanwhile; tidy against the newest list.
            if let current = SiteCache(paths: context.paths).read()?.sites {
                try? session.commit { deleteUnusedPictures(keeping: current) }
            }
        }
    }

    /// The `render <site id>` job: renders run one at a time, newest selection first (see `RenderQueue`). Renders
    /// what is queued; run by hand with nothing queued, renders `siteID`. Each render holds the site's render lock,
    /// writes the picture and its thumbnail, or records the failure, which is retried after 24 hours.
    public func render(siteID: String) async {
        guard !context.settings.isDemo, let session = try? AccountSession(paths: context.paths), context.isSignedIn else { return }
        let queue = RenderQueue(paths: context.paths)
        if queue.isEmpty {
            try? session.commit { try queue.request(siteID) }
        }
        await queue.drain { siteID in
            await renderIfNeeded(siteID: siteID)
        }
    }

    // MARK: Steps

    private func fetchMissing(for pictures: DeployPictures, with downloader: PictureDownloader, session: AccountSession) async {
        if pictures.needsScreenshot(at: context.now()), let url = pictures.screenshotURL {
            do {
                let image = try await downloader.screenshot(from: url)
                try session.commit { try pictures.save(image, as: .screenshot) }
            } catch {
                try? session.commit { record(error, of: .screenshot, for: pictures) }
            }
        }
        if pictures.needsFavicon(at: context.now()) {
            do {
                try await downloader.favicon(of: pictures.siteURL) { data in
                    try session.commit { try pictures.saveFavicon(data) }
                }
            } catch {
                try? session.commit { record(error, of: .favicon, for: pictures) }
            }
        }
        if pictures.needsFramingCheck {
            let check = await downloader.framingCheck(of: pictures.siteURL)
            try? session.commit { try pictures.save(check) }
        }
        try? session.commit { cutThumbnail(for: pictures) }
    }

    private func renderIfNeeded(siteID: String) async {
        guard let session = try? AccountSession(paths: context.paths),
              let site = SiteCache(paths: context.paths).site(id: siteID),
              let pictures = DeployPictures(site, in: context.paths.picturesFolder),
              pictures.needsRender(at: context.now())
        else { return }
        await JobLock(.render(siteID: siteID), paths: context.paths).tryHolding {
            do {
                let temporary = FileManager.default.temporaryDirectory.appending(path: "netlify-render-" + UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: temporary) }
                let staged = temporary.appending(path: site.fileSafeID).appending(path: pictures.folder.lastPathComponent)
                    .appending(path: "render.png")
                try FileManager.default.createDirectory(at: staged.deletingLastPathComponent(), withIntermediateDirectories: true)
                try await renderPage(pictures.siteURL, staged)
                try session.commit {
                    try FileManager.default.createDirectory(at: pictures.folder, withIntermediateDirectories: true)
                    try Data(contentsOf: staged).write(to: pictures.file(.render), options: .atomic)
                    pictures.clearFailure(of: .render)
                }
            } catch {
                try? session.commit { record(error, of: .render, for: pictures) }
            }
            try? session.commit { cutThumbnail(for: pictures) }
        }
    }

    private func cutThumbnail(for pictures: DeployPictures) {
        do {
            try pictures.cutThumbnailIfMissing(at: context.now())
        } catch {
            Log.write("thumbnail for \(pictures.siteURL.absoluteString): \(error.localizedDescription)")
        }
    }

    private func record(_ error: any Error, of kind: PictureKind, for pictures: DeployPictures) {
        let reason = error.localizedDescription
        Log.write("\(kind.rawValue) for \(pictures.siteURL.absoluteString): \(reason)")
        pictures.recordFailure(of: kind, at: context.now(), reason: reason)
    }

    /// Delete picture files nothing uses any more: folders of sites that are gone, folders of deploys that are no
    /// longer published, and thumbnails a better picture has replaced.
    private func deleteUnusedPictures(keeping sites: [Site]) {
        let picturesFolder = context.paths.picturesFolder
        let current = Dictionary(
            sites.compactMap { site in DeployPictures(site, in: picturesFolder).map { (site.fileSafeID, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
        for siteFolder in Self.subfolders(of: picturesFolder) {
            guard let pictures = current[siteFolder.lastPathComponent] else {
                try? FileManager.default.removeItem(at: siteFolder)
                continue
            }
            for deployFolder in Self.subfolders(of: siteFolder)
            where deployFolder.standardizedFileURL != pictures.folder.standardizedFileURL {
                try? FileManager.default.removeItem(at: deployFolder)
            }
            pictures.deleteReplacedThumbnails()
        }
    }

    /// The folders directly inside `folder`; files (such as the render queue) are left alone.
    private static func subfolders(of folder: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )) ?? []
        return items.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
    }
}
