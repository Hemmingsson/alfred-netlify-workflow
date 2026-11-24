import NetlifyCore

/// A site's production state, as far as the window flags it. Only exceptions are shown; `published` is the norm.
enum SiteState: Equatable, Sendable {
    /// The newest production deploy (not the live one) failed.
    case failed(Deploy)
    /// The newest production deploy (not the live one) is still building.
    case building(Deploy)
    /// Auto publishing is stopped.
    case locked
    case notPublished
    case published

    /// Failed and Building come from the newest deploy, only when it isn't the live one, and win over Locked.
    init(_ site: Site) {
        if let newest = site.newestDeploy, newest.id != site.publishedDeploy?.id {
            switch newest.phase {
            case .failed: self = .failed(newest); return
            case .building: self = .building(newest); return
            default: break
            }
        }
        guard let published = site.publishedDeploy else { self = .notPublished; return }
        self = published.isLocked ? .locked : .published
    }

    /// The row's state label; nil when published.
    var label: String? {
        switch self {
        case .failed: "Failed"
        case .building: "Building"
        case .locked: "Locked"
        case .notPublished: "Not published"
        case .published: nil
        }
    }

    var colour: Colour {
        switch self {
        case .failed: .red
        case .building: .orange
        case .locked: .yellow
        case .notPublished, .published: .secondaryLabel
        }
    }

    /// The deploy the LATEST DEPLOY column describes: the newest one when it failed or is building, else the live one.
    func describedDeploy(of site: Site) -> Deploy? {
        switch self {
        case .failed(let deploy), .building(let deploy): deploy
        default: site.publishedDeploy
        }
    }
}
