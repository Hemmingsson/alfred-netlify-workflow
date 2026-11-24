import Foundation
import NetlifyCore
import Testing

@Suite("Untrusted text can't fill in Alfred placeholders")
struct SafeTextTests {
    @Test func placeholdersAreBroken() {
        let defused = SafeText.defuse("https://x.test/{var:token}?{VALUE:searchField.text}")
        #expect(!defused.contains("{var:"))
        #expect(!defused.contains("{VALUE:"))
        #expect(defused.contains("var:token"))
    }

    @Test func otherBracesAreLeftAlone() {
        #expect(SafeText.defuse("{\"a\": 1} {variable}") == "{\"a\": 1} {variable}")
    }

    @Test func restoreUndoesDefuse() {
        let text = "copy:https://x.test/{data:uid}"
        #expect(SafeText.restore(SafeText.defuse(text)) == text)
    }

    @Test func encodingDefusesButOurPlaceholdersStay() throws {
        let filter = DataFilter(field: "match", match: .value("searchField.text"))
        let reply = WindowReply(update: [
            "sites": ComponentChange(placeholder: "{var:x}", data: DataSource(rows: [], filter: filter)),
        ])
        let json = try String(decoding: reply.json(), as: UTF8.self)
        #expect(json.contains("\"{value:searchField.text}\""))
        #expect(!json.contains("{var:x}"))
    }
}
