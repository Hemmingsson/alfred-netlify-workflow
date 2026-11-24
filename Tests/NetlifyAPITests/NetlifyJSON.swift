import Foundation

/// Netlify API answers for tests, built as JSON objects so each test sets only what it is about.
enum NetlifyJSON {
    /// A site as `GET /sites` lists it; `published` nil means never published.
    static func site(
        id: String,
        createdAt: String = "2026-01-01T10:00:00.000Z",
        updatedAt: String = "2026-01-01T10:00:00.000Z",
        published: [String: Any]? = nil,
        usesForms: Bool = false
    ) -> [String: Any] {
        var site: [String: Any] = [
            "id": id,
            "name": "site-\(id)",
            "url": "http://site-\(id).netlify.app",
            "ssl_url": "https://site-\(id).netlify.app",
            "default_domain": "site-\(id).netlify.app",
            "created_at": createdAt,
            "updated_at": updatedAt,
            "ssl": true,
            "use_forms": usesForms,
        ]
        site["published_deploy"] = published
        return site
    }

    /// A deploy; `ready` ones get a publish time.
    static func deploy(
        id: String,
        state: String = "ready",
        context: String = "production",
        createdAt: String = "2026-01-01T10:00:00.000Z"
    ) -> [String: Any] {
        var deploy: [String: Any] = ["id": id, "state": state, "context": context, "created_at": createdAt]
        if state == "ready" {
            deploy["published_at"] = createdAt
        }
        return deploy
    }

    /// `value` as a JSON body.
    static func body(_ value: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: value)
    }
}
