import Foundation
import NetlifyAPI
import NetlifyCore

extension Context {
    /// The real thing: settings and paths from the environment, URLSession, the Keychain, detached jobs of this
    /// binary, and the Mac. The workflow folder is the folder this binary is in.
    static func live(environment: [String: String], executable: URL) -> Context {
        let settings = Settings(environment: environment)
        let paths = Paths(environment: environment, settings: settings, workflowFolder: executable.deletingLastPathComponent())
        return Context(
            settings: settings,
            paths: paths,
            http: URLSessionHTTPClient(),
            tokens: KeychainTokenStore(),
            jobs: DetachedJobLauncher(executable: executable, log: paths.jobsLog, environment: environment),
            system: MacSystemActions(bundleID: settings.bundleID)
        )
    }
}
