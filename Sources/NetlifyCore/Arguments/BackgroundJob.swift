/// Slow work that runs in its own detached process: `netlify <arguments>`.
public enum BackgroundJob: Equatable, Hashable, Sendable {
    /// Fetch every site into the cache.
    case refresh
    /// Download screenshots and favicons, check framing, cut thumbnails, tidy.
    case pictures
    /// Render one site's page to a picture (started when it is selected).
    case render(siteID: String)
    /// Browser sign-in through a Netlify OAuth ticket, for one click on Sign in (`SignInProgress.attempt`; nil when
    /// started by hand).
    case signIn(attempt: String?)

    /// The command-line arguments that run this job.
    public var arguments: [String] {
        switch self {
        case .refresh: ["refresh"]
        case .pictures: ["pictures"]
        case .render(let siteID): ["render", siteID]
        case .signIn(let attempt): ["sign-in"] + (attempt.map { [$0] } ?? [])
        }
    }

    /// The job these arguments run, or nil.
    public init?(arguments: [String]) {
        switch arguments.first {
        case "refresh" where arguments.count == 1: self = .refresh
        case "pictures" where arguments.count == 1: self = .pictures
        case "render" where arguments.count == 2: self = .render(siteID: arguments[1])
        case "sign-in" where arguments.count == 1: self = .signIn(attempt: nil)
        case "sign-in" where arguments.count == 2: self = .signIn(attempt: arguments[1])
        default: return nil
        }
    }

    /// The lock file's name; one lock per job (so one render per site).
    var lockName: String {
        switch self {
        case .render(let siteID):
            "render-" + Paths.fileSafe(siteID)
        default: arguments[0]
        }
    }
}
