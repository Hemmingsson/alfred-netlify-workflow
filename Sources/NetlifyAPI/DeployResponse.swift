import Foundation
import NetlifyCore

/// A deploy as Netlify describes it: a site's `published_deploy`, or an entry of `GET /sites/{id}/deploys`.
struct DeployResponse: Decodable {
    var id: String
    var state: String?
    var branch: String?
    var commitRef: String?
    var committer: String?
    var title: String?
    var deploySource: String?
    var createdAt: Date
    var publishedAt: Date?
    var errorMessage: String?
    var screenshotURL: String?
    var framework: String?
    var availableFunctions: [IgnoredJSON]?
    var functionSchedules: [IgnoredJSON]?
    var edgeFunctionsPresent: Bool?
    var locked: Bool?

    enum CodingKeys: String, CodingKey {
        case id, state, branch, committer, title, framework, locked
        case commitRef = "commit_ref"
        case deploySource = "deploy_source"
        case createdAt = "created_at"
        case publishedAt = "published_at"
        case errorMessage = "error_message"
        case screenshotURL = "screenshot_url"
        case availableFunctions = "available_functions"
        case functionSchedules = "function_schedules"
        case edgeFunctionsPresent = "edge_functions_present"
    }

    var deploy: Deploy {
        Deploy(
            id: id,
            state: state ?? "",
            branch: branch.nonEmpty,
            commitRef: commitRef.nonEmpty,
            committer: committer.nonEmpty,
            title: title.nonEmpty,
            source: deploySource.nonEmpty,
            createdAt: createdAt,
            publishedAt: publishedAt,
            errorMessage: errorMessage.nonEmpty,
            framework: framework.nonEmpty,
            functionCount: availableFunctions?.count ?? 0,
            scheduledFunctionCount: functionSchedules?.count ?? 0,
            hasEdgeFunctions: edgeFunctionsPresent ?? false,
            isLocked: locked ?? false
        )
    }
}

/// Any JSON value, read and thrown away: for lists we only count.
struct IgnoredJSON: Decodable {
    init(from decoder: any Decoder) {}
}
