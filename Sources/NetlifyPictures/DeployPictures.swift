import CoreGraphics
import Foundation
import NetlifyCore

/// The picture files of one site's published deploy, in `pictures/<site id>/<deploy id>/`:
///
///     screenshot.png              Netlify's screenshot, converted
///     render.png                  our own 1440×900 render
///     thumbnail-render.png        320×200, cut from the best picture; named after its source, so a better picture
///     thumbnail-screenshot.png    gives a new file name and Alfred can't show a stale cached one
///     favicon.svg | favicon.png   the site's icon (SVG kept, others scaled to 64 px)
///     framing.json                FramingCheck
///     <kind>-failed.json          FailedAttempt, until it is retried
///
/// A new deploy gets a new folder, so everything is fetched again for it; the pictures job deletes the old one.
struct DeployPictures: Sendable {
    static let thumbnailWidth = 320
    static let thumbnailHeight = 200
    static let faviconSize = 64

    let folder: URL
    /// Netlify's screenshot of this deploy, when it has one.
    let screenshotURL: URL?
    /// The site's address.
    let siteURL: URL

    /// Nil for sites without pictures: never published, or without an address.
    init?(_ site: Site, in picturesFolder: URL) {
        guard let deploy = site.publishedDeploy, let url = site.url else { return nil }
        folder = picturesFolder
            .appending(path: site.fileSafeID, directoryHint: .isDirectory)
            .appending(path: Paths.fileSafe(deploy.id), directoryHint: .isDirectory)
        screenshotURL = site.screenshotURL
        siteURL = url
    }

    // MARK: Files

    /// `<kind>.png`: a full-size picture, or a favicon that isn't SVG.
    func file(_ kind: PictureKind) -> URL {
        folder.appending(path: "\(kind.rawValue).png")
    }

    func thumbnail(of kind: PictureKind) -> URL {
        folder.appending(path: "thumbnail-\(kind.rawValue).png")
    }

    var faviconSVG: URL { folder.appending(path: "favicon.svg") }
    var framingFile: URL { folder.appending(path: "framing.json") }

    func failureFile(_ kind: PictureKind) -> URL {
        folder.appending(path: "\(kind.rawValue)-failed.json")
    }

    // MARK: Lookups

    /// The best full-size picture there is: the render, else the screenshot.
    var bestKind: PictureKind? {
        PictureKind.fullSize.first { exists(file($0)) }
    }

    var bestPicture: URL? { bestKind.map(file) }

    /// The thumbnail of the best picture, once it was cut.
    var thumbnail: URL? {
        bestKind.map(thumbnail(of:)).flatMap { exists($0) ? $0 : nil }
    }

    var favicon: URL? {
        [faviconSVG, file(.favicon)].first(where: exists)
    }

    var framing: FramingCheck? { JSON.read(FramingCheck.self, from: framingFile) }

    func failure(_ kind: PictureKind) -> FailedAttempt? {
        JSON.read(FailedAttempt.self, from: failureFile(kind))
    }

    // MARK: What is missing

    func needsScreenshot(at now: Date) -> Bool {
        screenshotURL != nil && !exists(file(.screenshot)) && !failedRecently(.screenshot, at: now)
    }

    func needsFavicon(at now: Date) -> Bool {
        favicon == nil && !failedRecently(.favicon, at: now)
    }

    var needsFramingCheck: Bool { framing == nil }

    var needsThumbnail: Bool { bestKind != nil && thumbnail == nil }

    func needsRender(at now: Date) -> Bool {
        !exists(file(.render)) && !failedRecently(.render, at: now)
    }

    /// True when the `pictures` job has something to do here (renders are started separately).
    func needsPicturesJob(at now: Date) -> Bool {
        needsScreenshot(at: now) || needsFavicon(at: now) || needsFramingCheck || needsThumbnail
    }

    private func failedRecently(_ kind: PictureKind, at now: Date) -> Bool {
        failure(kind)?.blocksRetry(at: now) ?? false
    }

    // MARK: Writing

    /// Store a full-size picture as PNG, replacing any record of failing to get it.
    func save(_ image: CGImage, as kind: PictureKind) throws {
        try image.writePNG(to: file(kind))
        clearFailure(of: kind)
    }

    /// Store a favicon: SVG as it is, anything else ImageIO reads as a PNG at most 64 px across.
    func saveFavicon(_ data: Data) throws {
        if Self.isSVG(data) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: faviconSVG, options: .atomic)
        } else {
            guard let image = CGImage.decoded(from: data)?.scaledToFit(longestSide: Self.faviconSize) else {
                throw PictureError.notAnImage
            }
            try image.writePNG(to: file(.favicon))
        }
        clearFailure(of: .favicon)
    }

    func save(_ check: FramingCheck) throws {
        try JSON.write(check, to: framingFile)
    }

    func recordFailure(of kind: PictureKind, at date: Date, reason: String) {
        try? JSON.write(FailedAttempt(failedAt: date, reason: reason), to: failureFile(kind))
    }

    func clearFailure(of kind: PictureKind) {
        try? FileManager.default.removeItem(at: failureFile(kind))
    }

    /// Cut the thumbnail of the best picture when it is missing. A picture that can't be read is deleted and counted
    /// as a failed fetch, so it is fetched (or rendered) again later instead of being retried on every pulse.
    func cutThumbnailIfMissing(at now: Date) throws {
        guard let kind = bestKind, !exists(thumbnail(of: kind)) else { return }
        let picture = file(kind)
        guard let thumbnail = CGImage.decoded(contentsOf: picture)?
            .croppedToCover(width: Self.thumbnailWidth, height: Self.thumbnailHeight)
        else {
            try? FileManager.default.removeItem(at: picture)
            recordFailure(of: kind, at: now, reason: PictureError.notAnImage.localizedDescription)
            throw PictureError.notAnImage
        }
        try thumbnail.writePNG(to: self.thumbnail(of: kind))
    }

    /// Delete thumbnails a better picture has replaced.
    func deleteReplacedThumbnails() {
        guard let best = bestKind else { return }
        for kind in PictureKind.fullSize where kind != best {
            try? FileManager.default.removeItem(at: thumbnail(of: kind))
        }
    }

    // MARK: Helpers

    /// SVG text, not an HTML page served in its place (single-page sites answer every path with their page).
    static func isSVG(_ data: Data) -> Bool {
        let start = String(decoding: data.prefix(1024), as: UTF8.self).lowercased()
        return start.contains("<svg") && !start.contains("<html") && !start.contains("<!doctype html")
    }

    private func exists(_ file: URL) -> Bool {
        FileManager.default.fileExists(atPath: file.path)
    }
}

/// A fetch or render that failed, and when; it isn't tried again until `retryAfter` has passed.
struct FailedAttempt: Codable, Equatable, Sendable {
    /// How long a failure stands before the next try.
    static let retryAfter: TimeInterval = 24 * 60 * 60

    var failedAt: Date
    /// What went wrong, for the log and for whoever looks in the folder.
    var reason: String

    /// True while it is too soon to try again.
    func blocksRetry(at now: Date) -> Bool {
        now.timeIntervalSince(failedAt) < Self.retryAfter
    }
}
