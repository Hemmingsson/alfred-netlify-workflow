import Foundation

/// The pictures the window shows, and starting the jobs that make them. NetlifyPictures' `PictureStore` is the real
/// one; window tests use a fake. Lookups only read files, so they are fast enough for every window reply.
public protocol PictureLibrary: Sendable {
    /// The 320×200 row thumbnail, when there is one. A new picture gets a new file name, so Alfred reloads it.
    func thumbnail(for site: Site) -> URL?
    /// The best full-size picture of the published deploy: our own render, else Netlify's screenshot.
    func picture(for site: Site) -> URL?
    /// The site's favicon (PNG or SVG), when one was found.
    func favicon(for site: Site) -> URL?
    /// Whether the published deploy may be shown in an iframe; nil until it was checked.
    func allowsFraming(_ site: Site) -> Bool?
    /// Start the `pictures` job when anything is missing and it isn't running. True while pictures are still
    /// coming (the job or a render is running, or was just started), so the window keeps pulsing.
    func startPicturesJobIfNeeded(for sites: [Site]) -> Bool
    /// The user selected a site: start rendering it, once per deploy. True when a render started.
    func startRenderJobIfNeeded(_ site: Site) -> Bool
}
