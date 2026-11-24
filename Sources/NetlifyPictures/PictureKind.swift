/// What the picture jobs fetch or make for a deploy. Each is stored as `<kind>.png` and its failures as
/// `<kind>-failed.json`; a full-size picture's thumbnail is `thumbnail-<kind>.png`.
enum PictureKind: String, CaseIterable, Sendable {
    /// Netlify's screenshot of the deploy.
    case screenshot
    /// Our own render of the page, made when the site is selected.
    case render
    /// The site's icon.
    case favicon

    /// The full-size pictures, best first.
    static let fullSize: [PictureKind] = [.render, .screenshot]
}
