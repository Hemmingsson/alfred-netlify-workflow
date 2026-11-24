import Foundation
import NetlifyAPI
import Testing

/// Uses the real login Keychain, under a test service name, so it only runs when asked:
/// `NETLIFY_KEYCHAIN_TESTS=1 swift test --filter KeychainTokenStoreTests`.
@Suite("Keychain token store", .enabled(if: ProcessInfo.processInfo.environment["NETLIFY_KEYCHAIN_TESTS"] == "1"))
struct KeychainTokenStoreTests {
    let store = KeychainTokenStore(service: "alfred-netlify-workflow-tests", account: "test-token")

    @Test func savesReplacesAndDeletes() throws {
        try store.delete()
        #expect(try store.read() == nil)

        try store.save("first")
        #expect(try store.read() == "first")

        try store.save("second")
        #expect(try store.read() == "second")

        try store.delete()
        #expect(try store.read() == nil)
        try store.delete()
    }

    @Test func usesThePythonVersionsItem() {
        let store = KeychainTokenStore()
        #expect(store.service == "alfred-netlify-workflow")
        #expect(store.account == "netlify-access-token")
    }
}
