/// Where the Netlify access token is kept: the Keychain (`KeychainTokenStore`), or memory in tests.
public protocol TokenStore: Sendable {
    func read() throws -> String?
    func save(_ token: String) throws
    /// Deleting a token that isn't there is not an error.
    func delete() throws
}
