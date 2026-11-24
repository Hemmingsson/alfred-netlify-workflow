import Foundation
import NetlifyCLI
import NetlifyCore
import Testing

@Suite("Command line")
struct CommandTests {
    @Test func parsesEachKind() {
        #expect(Command(arguments: ["ui", "selected", "s1"]) == .ui(.selected(siteID: "s1", previewSource: "")))
        #expect(Command(arguments: ["ui"]) == .ui(.load(query: "")))
        #expect(Command(arguments: ["action", "copy:https://bland.band"]) == .action(.copy("https://bland.band")))
        #expect(Command(arguments: ["ui", "sign-in"]) == .ui(.signIn))
        #expect(Command(arguments: ["sign-in", "a1"]) == .job(.signIn(attempt: "a1")))
        #expect(Command(arguments: ["render", "s1"]) == .job(.render(siteID: "s1")))
    }

    @Test(arguments: [
        Command.ui(.load(query: "")),
        .ui(.pulse(fingerprint: "f00d", selectedSiteID: "s1", previewSource: "file:///p.html")),
        .ui(.filtered(selectedSiteID: "s1", query: "Fix the {var:token} bug")),
        .action(.open(URL(string: "https://bland.band/?a=1&b=2")!)),
        .action(.copy("https://bland.band")),
        .job(.refresh),
        .job(.pictures),
        .job(.render(siteID: "s1")),
        .job(.signIn(attempt: nil)),
        .job(.signIn(attempt: "a1")),
    ])
    func roundTrips(command: Command) {
        #expect(Command(arguments: command.arguments) == command)
    }

    @Test func argumentsDefusedByTheWindowAreRestored() {
        let sent = ["ui", "filtered", "s1", SafeText.defuse("Fix {var:token}")]
        #expect(Command(arguments: sent) == .ui(.filtered(selectedSiteID: "s1", query: "Fix {var:token}")))
    }

    @Test func rejectsTheRest() {
        #expect(Command(arguments: []) == nil)
        #expect(Command(arguments: ["action"]) == nil)
        #expect(Command(arguments: ["action", "open:x", "extra"]) == nil)
        #expect(Command(arguments: ["action", "launch-missiles"]) == nil)
        #expect(Command(arguments: ["ui", "nope"]) == nil)
        #expect(Command(arguments: ["refresh", "now"]) == nil)
        #expect(Command(arguments: ["render"]) == nil)
    }
}
