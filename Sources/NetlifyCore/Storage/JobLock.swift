import Foundation

/// Marks a background job as running, with `flock` on a file in `locks/`. The kernel releases the lock when the
/// process ends, so a crashed job never leaves a stale lock behind.
public struct JobLock: Sendable {
    public let file: URL

    public init(_ job: BackgroundJob, paths: Paths, session: AccountSession? = nil) {
        let suffix: String
        switch job {
        case .refresh, .pictures: suffix = "-" + Paths.fileSafe(session?.generation ?? AccountSession.generation(paths: paths))
        default: suffix = ""
        }
        file = paths.locksFolder.appending(path: job.lockName + suffix + ".lock")
    }

    /// A lock that no single job owns, such as the one renderer all `render` jobs take turns at.
    public init(file: URL) {
        self.file = file
    }

    /// True while some process (this one included) holds the lock.
    public var isHeld: Bool {
        guard let descriptor = openFile() else { return false }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { return true }
        flock(descriptor, LOCK_UN)
        return false
    }

    /// Run `body` holding the lock; nil, without running it, when the lock is already held.
    public func tryHolding<T>(
        isolation: isolated (any Actor)? = #isolation,
        _ body: () async throws -> T
    ) async rethrows -> T? {
        guard let descriptor = openFile() else { return try await body() }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { return nil }
        return try await body()
    }

    /// Run `body` holding the lock, first waiting for whoever holds it.
    public func holding<T>(
        isolation: isolated (any Actor)? = #isolation,
        _ body: () async throws -> T
    ) async rethrows -> T {
        guard let descriptor = openFile() else { return try await body() }
        defer { close(descriptor) }
        flock(descriptor, LOCK_EX)
        return try await body()
    }

    /// The lock file, opened (and created with its folder) for locking; nil when that isn't possible, and then the
    /// job runs unlocked rather than not at all.
    private func openFile() -> Int32? {
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(file.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o644)
        return descriptor >= 0 ? descriptor : nil
    }
}
