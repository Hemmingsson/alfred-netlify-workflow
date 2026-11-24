import Foundation

/// How far a browser sign-in has come, so the window can show it. The window writes `connecting` when Sign in is
/// clicked; the `sign-in` job keeps it fresh while it waits, writes `failed` when it ends without a token, and
/// deletes it once the token is saved. Cancel deletes it too.
///
/// `attempt` names one click on Sign in. A job works only for its own attempt: when the file names another attempt
/// (Try again) or is gone (Cancel), the job stops at its next check.
public struct SignInProgress: Codable, Equatable, Sendable {
    public enum Stage: String, Codable, Sendable {
        /// Creating the ticket, or waiting for the user to approve it in the browser.
        case connecting
        /// Ended without a token: denied, expired, timed out or failed. `message` says which.
        case failed
    }

    public var attempt: String
    public var stage: Stage
    /// For `failed`: what went wrong, worded for people.
    public var message: String?
    public var updatedAt: Date

    public init(attempt: String, stage: Stage, message: String? = nil, updatedAt: Date) {
        self.attempt = attempt
        self.stage = stage
        self.message = message
        self.updatedAt = updatedAt
    }

    /// How long a `connecting` file counts as live without the job holding its lock: the job has been launched but
    /// hasn't started yet. After that, a `connecting` file with no job behind it is left over from a crash.
    public static let startGrace: TimeInterval = 20

    // MARK: The file

    /// The current sign-in, or nil when none is running or recorded.
    public static func read(paths: Paths) -> SignInProgress? {
        JSON.read(SignInProgress.self, from: paths.signInFile)
    }

    /// Replace the file (atomic, so a reader never sees half of it).
    public func write(paths: Paths) throws {
        try AccountSession.locked(paths: paths) {
            try JSON.write(self, to: paths.signInFile)
        }
    }

    /// Delete the file: signed in, cancelled or signed out.
    public static func clear(paths: Paths) {
        try? AccountSession.locked(paths: paths) {
            try FileManager.default.removeItem(at: paths.signInFile)
        }
    }

    /// Finish only the attempt still awaited by the window. Cancellation, retry and sign-out use the same lock,
    /// so none can slip between checking the attempt, saving its token and clearing its progress.
    public static func complete(attempt: String, paths: Paths, saveToken: () throws -> Void) throws -> Bool {
        try AccountSession.locked(paths: paths) {
            guard let progress = read(paths: paths), progress.attempt == attempt, progress.stage == .connecting else { return false }
            try paths.resetAccount(changingCredentials: saveToken)
            try FileManager.default.removeItem(at: paths.signInFile)
            return true
        }
    }

    /// Record a failure only if a retry or cancellation has not superseded it.
    public func writeIfCurrent(paths: Paths) throws {
        try AccountSession.locked(paths: paths) {
            guard let current = Self.read(paths: paths), current.attempt == attempt, current.stage == .connecting else { return }
            try JSON.write(self, to: paths.signInFile)
        }
    }
}
