import Foundation

/// The folders the app reads and writes.
///
///     <cache folder>/            alfred_workflow_cache
///       locks/                   one lock file per background job, and renderer.lock (JobLock)
///       jobs.log                 background jobs' stdout and stderr
///       ui-errors.log            the window script's stderr (sites.alfredui/scripts/ui)
///       sign-in.json             SignInProgress: how far a browser sign-in has come
///       account/                 everything about the signed-in account; sign-in and sign-out delete it
///         sites.json             SiteCache
///         refresh-problem.json   SiteCache
///         pictures/              NetlifyPictures: one folder per site and deploy (DeployPictures), render-queue
///         previews/              NetlifyWindow: one live preview page per site (PreviewPages)
///
/// In demo mode the demo folder takes the place of `account/`.
public struct Paths: Equatable, Sendable {
    public let cacheFolder: URL
    /// Where `netlify`, `icon.png` and `github.png` are.
    public let workflowFolder: URL
    public let accountFolder: URL
    public let isDemo: Bool

    public init(cacheFolder: URL, workflowFolder: URL, demoFolder: URL? = nil) {
        self.cacheFolder = cacheFolder
        self.workflowFolder = workflowFolder
        self.accountFolder = demoFolder ?? cacheFolder.appending(path: "account", directoryHint: .isDirectory)
        self.isDemo = demoFolder != nil
    }

    /// The cache folder from `alfred_workflow_cache`, else Alfred's usual place for this bundle id under `HOME`.
    public init(environment: [String: String], settings: Settings, workflowFolder: URL) {
        func folder(_ name: String) -> URL? {
            environment[name].nonEmpty.map { URL(filePath: $0, directoryHint: .isDirectory) }
        }
        let home = folder("HOME") ?? URL.homeDirectory
        let cache = folder("alfred_workflow_cache")
            ?? home.appending(path: "Library/Caches/com.runningwithcrayons.Alfred/Workflow Data/\(settings.bundleID)", directoryHint: .isDirectory)
        self.init(cacheFolder: cache, workflowFolder: workflowFolder, demoFolder: settings.demoFolder)
    }

    public var locksFolder: URL { cacheFolder.appending(path: "locks", directoryHint: .isDirectory) }
    public var jobsLog: URL { cacheFolder.appending(path: "jobs.log") }
    public var signInFile: URL { cacheFolder.appending(path: "sign-in.json") }
    public var sitesFile: URL { accountFolder.appending(path: "sites.json") }
    public var refreshProblemFile: URL { accountFolder.appending(path: "refresh-problem.json") }
    public var picturesFolder: URL { accountFolder.appending(path: "pictures", directoryHint: .isDirectory) }
    public var previewsFolder: URL { accountFolder.appending(path: "previews", directoryHint: .isDirectory) }
    public var workflowIcon: URL { workflowFolder.appending(path: "icon.png") }
    public var githubIcon: URL { workflowFolder.appending(path: "github.png") }

    /// Invalidate outstanding jobs and delete the account cache. A token change shares the same short lock, so
    /// another process cannot capture the new generation with the old credentials. Never touches a demo folder.
    public func forgetAccount(changingCredentials: () throws -> Void = {}) throws {
        guard !isDemo else { return }
        try AccountSession.locked(paths: self) { try resetAccount(changingCredentials: changingCredentials) }
    }

    /// Caller holds the account lock. Clear old data before accepting new credentials.
    func resetAccount(changingCredentials: () throws -> Void) throws {
        try Data(UUID().uuidString.utf8).write(to: cacheFolder.appending(path: "account-generation"), options: .atomic)
        if FileManager.default.fileExists(atPath: accountFolder.path) {
            try FileManager.default.removeItem(at: accountFolder)
        }
        try changingCredentials()
    }

    /// `text` with everything but ASCII letters, digits, `-` and `_` removed, for file names made from ids.
    public static func fileSafe(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter {
            $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_")
        }))
    }
}
