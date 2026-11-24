import Foundation
@testable import NetlifyCLI
import NetlifyCore
import NetlifyTesting
import Testing

@Suite("Finishing the window")
struct WorkflowActionsTests {
    @Test func openOpensTheSiteAndSaysNothing() throws {
        let test = TestContext()
        let url = URL(string: "https://bland.band")!
        let message = try WorkflowActions(context: test.context).perform(.open(url))
        #expect(test.system.calls == [.opened(url)])
        #expect(message.isEmpty)
    }

    @Test(arguments: ["file:///Applications/Calculator.app", "x-apple.systempreferences:com.apple.preference", "javascript:alert(1)"])
    func openRefusesAnythingButWebAddresses(address: String) {
        let test = TestContext()
        let url = URL(string: address)!
        #expect(throws: WorkflowActionError.notAWebAddress(url)) {
            try WorkflowActions(context: test.context).perform(.open(url))
        }
        #expect(test.system.calls.isEmpty)
    }

    /// The text goes to Alfred's Post Notification object; the binary posts nothing itself.
    @Test func copyCopiesAndHandsAlfredTheConfirmation() throws {
        let test = TestContext()
        let message = try WorkflowActions(context: test.context).perform(.copy("https://bland.band"))
        #expect(test.system.calls == [.copied("https://bland.band")])
        #expect(message == "Copied https://bland.band")
    }
}
