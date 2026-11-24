import NetlifyCore

/// A TokenStore whose every call fails, like a locked Keychain.
struct BrokenTokenStore: TokenStore {
    struct Failure: Error {}

    func read() throws -> String? { throw Failure() }
    func save(_ token: String) throws { throw Failure() }
    func delete() throws { throw Failure() }
}
