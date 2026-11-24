import CoreGraphics
import Foundation
import NetlifyCore

/// The pictures in `account/pictures/`: finding them for the window, and starting the jobs that make them.
/// One picture per deploy: Netlify's screenshot first, replaced by our own render once the site was selected.
/// Lookups only read files. In demo mode nothing is fetched or rendered, and no site is framed (picture only).
public struct PictureStore: PictureLibrary {
    let context: Context

    public init(context: Context) {
        self.context = context
    }

    public func thumbnail(for site: Site) -> URL? {
        pictures(of: site)?.thumbnail
    }

    public func picture(for site: Site) -> URL? {
        pictures(of: site)?.bestPicture
    }

    public func favicon(for site: Site) -> URL? {
        pictures(of: site)?.favicon
    }

    public func allowsFraming(_ site: Site) -> Bool? {
        if context.settings.isDemo { return false }
        return pictures(of: site)?.framing?.allowsFraming
    }

    public func startPicturesJobIfNeeded(for sites: [Site]) -> Bool {
        guard !context.settings.isDemo else { return false }
        let renderQueue = RenderQueue(paths: context.paths)
        if JobLock(.pictures, paths: context.paths).isHeld || renderQueue.isRendering || !renderQueue.isEmpty {
            return true
        }
        let now = context.now()
        guard sites.contains(where: { pictures(of: $0)?.needsPicturesJob(at: now) == true }) else { return false }
        context.jobs.launch(.pictures)
        return true
    }

    public func startRenderJobIfNeeded(_ site: Site) -> Bool {
        guard !context.settings.isDemo,
              let pictures = pictures(of: site),
              pictures.needsRender(at: context.now())
        else { return false }
        do {
            try RenderQueue(paths: context.paths).request(site.id)
        } catch {
            return false
        }
        context.jobs.launch(.render(siteID: site.id))
        return true
    }

    /// For the demo tool: store ready-made pictures for a demo site, as if they had been fetched, and cut the
    /// thumbnail. The screenshot may be any image ImageIO reads; it is stored as PNG.
    public func adoptDemoPictures(screenshot: URL?, favicon: URL?, for site: Site) throws {
        guard let pictures = pictures(of: site) else { throw PictureError.unpublished }
        if let screenshot {
            guard let image = CGImage.decoded(contentsOf: screenshot) else { throw PictureError.notAnImage }
            try pictures.save(image, as: .screenshot)
        }
        if let favicon {
            try pictures.saveFavicon(try Data(contentsOf: favicon))
        }
        try pictures.cutThumbnailIfMissing(at: context.now())
    }

    private func pictures(of site: Site) -> DeployPictures? {
        DeployPictures(site, in: context.paths.picturesFolder)
    }
}
