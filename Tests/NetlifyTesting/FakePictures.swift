import Foundation
import NetlifyCore

/// A PictureLibrary with fixed answers per site id; records render requests.
public final class FakePictures: PictureLibrary {
    private let thumbnails: [String: URL]
    private let pictures: [String: URL]
    private let favicons: [String: URL]
    private let framing: [String: Bool]
    private let stillFetching: Bool
    private let startsRenders: Bool
    private let renderLog = Locked<[String]>([])

    public init(
        thumbnails: [String: URL] = [:],
        pictures: [String: URL] = [:],
        favicons: [String: URL] = [:],
        framing: [String: Bool] = [:],
        stillFetching: Bool = false,
        startsRenders: Bool = false
    ) {
        self.thumbnails = thumbnails
        self.pictures = pictures
        self.favicons = favicons
        self.framing = framing
        self.stillFetching = stillFetching
        self.startsRenders = startsRenders
    }

    /// Site ids `startRenderJobIfNeeded` was called with.
    public var renderRequests: [String] { renderLog.value }

    public func thumbnail(for site: Site) -> URL? { thumbnails[site.id] }

    public func picture(for site: Site) -> URL? { pictures[site.id] }

    public func favicon(for site: Site) -> URL? { favicons[site.id] }

    public func allowsFraming(_ site: Site) -> Bool? { framing[site.id] }

    public func startPicturesJobIfNeeded(for sites: [Site]) -> Bool { stillFetching }

    public func startRenderJobIfNeeded(_ site: Site) -> Bool {
        renderLog.withLock { $0.append(site.id) }
        return startsRenders
    }
}
