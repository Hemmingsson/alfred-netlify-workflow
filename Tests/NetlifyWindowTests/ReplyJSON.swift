import Foundation
import NetlifyCore

/// A reply as Alfred receives it: decoded back into plain JSON values, for checking keys and values in tests.
struct ReplyJSON {
    let object: [String: Any]
    let text: String

    init(_ reply: WindowReply) throws {
        let data = try reply.json()
        text = String(decoding: data, as: UTF8.self)
        object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    /// `update.ids.<id>`.
    func update(_ id: String) -> [String: Any]? {
        ((object["update"] as? [String: Any])?["ids"] as? [String: Any])?[id] as? [String: Any]
    }

    /// `replace.ids.<id>`.
    func replaced(_ id: String) -> [String: Any]? {
        ((object["replace"] as? [String: Any])?["ids"] as? [String: Any])?[id] as? [String: Any]
    }

    var variables: [String: String] { object["variables"] as? [String: String] ?? [:] }

    var pulseInterval: Double? { (object["pulse"] as? [String: Any])?["interval"] as? Double }

    /// The list's rows.
    var rows: [[String: Any]] {
        (update("sites")?["data"] as? [String: Any])?["src"] as? [[String: Any]] ?? []
    }

    var status: String? { update("statusLabel")?["text"] as? String }

    /// The empty state's centred message and its purple button.
    var emptyTitle: String? { update("emptyTitle")?["text"] as? String }
    var emptyDetail: String? { update("emptyDetail")?["text"] as? String }
    var emptyAction: String? { update("emptyActionButton")?["text"] as? String }
}
