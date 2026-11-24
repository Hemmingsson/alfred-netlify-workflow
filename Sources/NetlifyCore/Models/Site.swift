import Foundation

/// A Netlify site (a "project" in Netlify's dashboard): what the window shows about it. Also the cache format.
public struct Site: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    /// The Netlify project name, e.g. `dulcet-paletas-403ab7`.
    public var name: String
    /// The production address: `https://` when the site has a certificate. Nil when Netlify gives none.
    public var url: URL?
    public var customDomain: String?
    public var domainAliases: [String]
    /// The `*.netlify.app` domain.
    public var netlifyDomain: String
    /// The project in Netlify's dashboard.
    public var adminURL: URL?
    public var createdAt: Date
    public var updatedAt: Date
    /// Netlify's own screenshot of the published deploy.
    public var screenshotURL: URL?
    /// The linked Git repository; nil for sites deployed by the CLI, the API or drag and drop.
    public var repository: Repository?
    public var hasSSL: Bool
    public var hasPassword: Bool
    public var usesForms: Bool
    /// Form and submission counts; only fetched for sites that use forms.
    public var forms: Forms?
    /// The deploy the site serves now; nil when nothing was ever published.
    public var publishedDeploy: Deploy?
    /// The newest production deploy, fetched for recently updated sites only. When it is not the published one, it
    /// may be building or have failed.
    public var newestDeploy: Deploy?

    /// How many forms a site has and how many submissions they hold.
    public struct Forms: Codable, Equatable, Sendable {
        public var count: Int
        public var submissions: Int

        public init(count: Int, submissions: Int) {
            self.count = count
            self.submissions = submissions
        }
    }

    public init(
        id: String,
        name: String,
        url: URL?,
        customDomain: String? = nil,
        domainAliases: [String] = [],
        netlifyDomain: String,
        adminURL: URL? = nil,
        createdAt: Date,
        updatedAt: Date,
        screenshotURL: URL? = nil,
        repository: Repository? = nil,
        hasSSL: Bool = true,
        hasPassword: Bool = false,
        usesForms: Bool = false,
        forms: Forms? = nil,
        publishedDeploy: Deploy? = nil,
        newestDeploy: Deploy? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.customDomain = customDomain
        self.domainAliases = domainAliases
        self.netlifyDomain = netlifyDomain
        self.adminURL = adminURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.screenshotURL = screenshotURL
        self.repository = repository
        self.hasSSL = hasSSL
        self.hasPassword = hasPassword
        self.usesForms = usesForms
        self.forms = forms
        self.publishedDeploy = publishedDeploy
        self.newestDeploy = newestDeploy
    }

    public var isPublished: Bool { publishedDeploy != nil }

    /// The id with everything but letters, digits, `-` and `_` removed: safe in a file name and in a path the window
    /// gets (Netlify ids are hex, but they come from outside).
    public var fileSafeID: String {
        Paths.fileSafe(id)
    }
}
