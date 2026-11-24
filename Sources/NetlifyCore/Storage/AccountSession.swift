import Foundation

/// A background job's account generation. Resetting the account invalidates outstanding results. Only local
/// reads and writes hold the lock: network requests and rendering never delay sign-out.
public struct AccountSession: Sendable {
    private let paths: Paths
    let generation: String

    public init(paths: Paths) throws {
        self.paths = paths
        generation = try Self.locked(paths: paths) { Self.generation(paths: paths) }
    }

    /// Commit a result only while it still belongs to the account that started the work.
    @discardableResult
    public func commit<T>(_ write: () throws -> T) throws -> T? {
        try Self.locked(paths: paths) {
            guard generation == Self.generation(paths: paths) else { return nil }
            return try write()
        }
    }

    static func generation(paths: Paths) -> String {
        (try? String(contentsOf: paths.cacheFolder.appending(path: "account-generation"), encoding: .utf8)) ?? "initial"
    }

    static func locked<T>(paths: Paths, _ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: paths.locksFolder, withIntermediateDirectories: true)
        let file = paths.locksFolder.appending(path: "account.lock")
        let descriptor = open(file.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
        return try body()
    }
}
