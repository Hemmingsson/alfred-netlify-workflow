import NetlifyCore
import NetlifyWindow
import Testing

@Suite("Window commands")
struct WindowCommandTests {
    @Test(arguments: [
        WindowCommand.load(query: "band"), .pulse(fingerprint: "f", selectedSiteID: "s1", previewSource: "/p.html"),
        .refresh(selectedSiteID: "s1", previewSource: "about:blank", query: ""), .selected(siteID: "s1", previewSource: "/p.html"), .filtered(selectedSiteID: "", query: "band x"),
        .finish(argument: "open:https://example.com"), .signIn, .cancelSignIn, .retry, .signOut,
    ])
    func readBackWhatTheyWrite(command: WindowCommand) {
        #expect(WindowCommand(arguments: command.arguments) == command)
    }

    @Test func noArgumentsLoadsAndMissingOnesAreEmpty() {
        #expect(WindowCommand(arguments: []) == .load(query: ""))
        #expect(WindowCommand(arguments: ["pulse"]) == .pulse(fingerprint: "", selectedSiteID: "", previewSource: ""))
        #expect(WindowCommand(arguments: ["nope"]) == nil)
    }

    @Test func argumentsAreRestoredFromSafeText() {
        let query = SafeText.defuse("{var:token}")
        #expect(WindowCommand(arguments: ["filtered", "s1", query]) == .filtered(selectedSiteID: "s1", query: "{var:token}"))
    }
}
