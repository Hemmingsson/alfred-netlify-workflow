import Foundation
import NetlifyCore
import Testing

@Suite("Replies encode to the window's JSON action format")
struct WindowReplyTests {
    /// The reply as a JSON object, to inspect.
    func object(_ reply: WindowReply) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: reply.json()) as! [String: Any]
    }

    @Test func nothingIsAnEmptyObject() throws {
        #expect(try String(decoding: WindowReply.nothing.json(), as: UTF8.self) == "{}")
    }

    @Test func updatesGoUnderIDsAndLeaveOutNils() throws {
        let reply = WindowReply(update: ["statusLabel": ComponentChange(text: "12 sites")], pulse: .stop)
        let json = try String(decoding: reply.json(), as: UTF8.self)
        #expect(json == #"{"pulse":{"interval":0},"update":{"ids":{"statusLabel":{"text":"12 sites"}}}}"#)
    }

    @Test func anEmptyImageIsNull() throws {
        let reply = WindowReply(update: ["pictureView": ComponentChange(image: .empty)])
        #expect(try String(decoding: reply.json(), as: UTF8.self) == #"{"update":{"ids":{"pictureView":{"image":null}}}}"#)
    }

    @Test func rowsAreFlatWithCellPrefixes() throws {
        let row = DataRow(
            uid: "s1",
            cells: [
                "rowTitle": ComponentChange(text: "bland.band", colour: .label),
                "rowThumbnail": ComponentChange(image: .symbol("globe")),
            ],
            values: [
                "match": .text("bland band"),
                "detail": .changes(["addressLabel": ComponentChange(text: "https://bland.band")]),
            ]
        )
        let reply = WindowReply(update: ["sites": ComponentChange(data: DataSource(rows: [row], filter: nil))])
        let data = try object(reply)["update"] as! [String: Any]
        let sites = (data["ids"] as! [String: Any])["sites"] as! [String: Any]
        let source = sites["data"] as! [String: Any]
        #expect(source["type"] as? String == "basic")
        let first = (source["src"] as! [[String: Any]])[0]
        #expect(first["uid"] as? String == "s1")
        #expect(first["rowTitle.text"] as? String == "bland.band")
        #expect(first["rowTitle.colour"] as? String == "labelColor")
        #expect((first["rowThumbnail.image"] as? [String: String]) == ["type": "symbol", "src": "globe"])
        #expect(first["match"] as? String == "bland band")
        #expect((first["detail"] as? [String: Any])?["addressLabel"] != nil)
    }

    @Test func aReplacedWebViewGoesUnderIDs() throws {
        let reply = WindowReply(replace: ["livePreview": .webView(id: "livePreview", src: "/p.html", opacity: 1)])
        let json = try String(decoding: reply.json(), as: UTF8.self)
        #expect(json == #"{"replace":{"ids":{"livePreview":{"id":"livePreview","opacity":1,"src":"/p.html","type":"webkitview"}}}}"#)
    }
}
