import Foundation

/// One deploy of a site: the published one or the newest production one.
public struct Deploy: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    /// Netlify's state name, e.g. `ready`, `building`, `error`. See `phase`.
    public var state: String
    public var branch: String?
    public var commitRef: String?
    public var committer: String?
    /// The commit message (all of it); nil for deploys without a commit.
    public var title: String?
    /// How it was deployed: `github`, `cli`, `api`, …
    public var source: String?
    public var createdAt: Date
    public var publishedAt: Date?
    public var errorMessage: String?
    /// Netlify's framework id, e.g. `svelte-kit`, `next`.
    public var framework: String?
    public var functionCount: Int
    public var scheduledFunctionCount: Int
    public var hasEdgeFunctions: Bool
    /// Auto publishing is stopped: new deploys don't go live.
    public var isLocked: Bool

    public init(
        id: String,
        state: String,
        branch: String? = nil,
        commitRef: String? = nil,
        committer: String? = nil,
        title: String? = nil,
        source: String? = nil,
        createdAt: Date,
        publishedAt: Date? = nil,
        errorMessage: String? = nil,
        framework: String? = nil,
        functionCount: Int = 0,
        scheduledFunctionCount: Int = 0,
        hasEdgeFunctions: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        self.state = state
        self.branch = branch
        self.commitRef = commitRef
        self.committer = committer
        self.title = title
        self.source = source
        self.createdAt = createdAt
        self.publishedAt = publishedAt
        self.errorMessage = errorMessage
        self.framework = framework
        self.functionCount = functionCount
        self.scheduledFunctionCount = scheduledFunctionCount
        self.hasEdgeFunctions = hasEdgeFunctions
        self.isLocked = isLocked
    }

    /// Where a deploy is in its life, folded from Netlify's many state names.
    public enum Phase: Sendable {
        case ready, building, failed, other
    }

    public var phase: Phase {
        switch state {
        case "ready": .ready
        case "error", "rejected": .failed
        case "new", "pending_review", "accepted", "enqueued", "building", "uploading", "uploaded",
             "preparing", "prepared", "processing", "processed", "retrying": .building
        default: .other
        }
    }
}
