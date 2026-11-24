import Foundation
import NetlifyCore
import Security

/// The access token as a generic password in the login Keychain, through the Security framework. The service and
/// account names are the ones the Python version used, so its users stay signed in (after one "allow" prompt).
public struct KeychainTokenStore: TokenStore {
    public let service: String
    public let account: String

    public init(service: String = "alfred-netlify-workflow", account: String = "netlify-access-token") {
        self.service = service
        self.account = account
    }

    public func read() throws -> String? {
        var query = itemQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        return (result as? Data).flatMap { String(data: $0, encoding: .utf8) }
    }

    public func save(_ token: String) throws {
        let secret = Data(token.utf8)
        let status = SecItemUpdate(itemQuery as CFDictionary, [kSecValueData: secret] as CFDictionary)
        if status == errSecItemNotFound {
            var item = itemQuery
            item[kSecAttrLabel] = "Alfred Netlify"
            item[kSecValueData] = secret
            try check(SecItemAdd(item as CFDictionary, nil))
        } else {
            try check(status)
        }
    }

    public func delete() throws {
        let status = SecItemDelete(itemQuery as CFDictionary)
        guard status != errSecItemNotFound else { return }
        try check(status)
    }

    /// The query that finds our one item.
    private var itemQuery: [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }
}

/// A Keychain call failed, with the Security framework's status code.
public struct KeychainError: Error, Equatable, LocalizedError {
    public let status: OSStatus

    public var errorDescription: String? {
        (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain error \(status)."
    }
}
