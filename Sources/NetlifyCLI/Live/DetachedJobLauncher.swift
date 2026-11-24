import Darwin
import Foundation
import NetlifyCore

/// Starts `<executable> <job arguments>` with posix_spawn in a new session (so Alfred ending the script doesn't end
/// it), stdin from /dev/null, stdout and stderr appended to `log`, and every other file descriptor closed, so the
/// job never holds Alfred's pipe open and Alfred doesn't wait for it. The job gets `environment`.
struct DetachedJobLauncher: JobLauncher {
    let executable: URL
    let log: URL
    let environment: [String: String]

    /// Past this size the log is started afresh, so it can't grow without end.
    static let logSizeLimit = 1 << 20

    func launch(_ job: BackgroundJob) {
        do {
            try prepareLog()
            let pid = try spawn(arguments: commandLine(for: job))
            // Reap the job if this process lives on; when it exits first, launchd adopts the job.
            DispatchQueue.global(qos: .utility).async {
                var status: Int32 = 0
                waitpid(pid, &status, 0)
            }
        } catch {
            Log.write("could not start \(job.arguments.joined(separator: " ")): \(error)")
        }
    }

    /// The job's argv: this binary, then the job's own arguments.
    func commandLine(for job: BackgroundJob) -> [String] {
        [executable.path] + job.arguments
    }

    /// The job's environment as `NAME=value` strings, sorted (stable for tests).
    var environmentStrings: [String] {
        environment.map { "\($0.key)=\($0.value)" }.sorted()
    }

    /// Creates the log's folder, and drops a log that grew past `logSizeLimit`.
    private func prepareLog() throws {
        let folder = log.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let size = (try? FileManager.default.attributesOfItem(atPath: log.path)[.size] as? Int) ?? 0
        if size > Self.logSizeLimit {
            try? FileManager.default.removeItem(at: log)
        }
    }

    /// posix_spawn with a new session, default signal handling and only the three standard descriptors.
    private func spawn(arguments: [String]) throws -> pid_t {
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        let flags = POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF
        posix_spawnattr_setflags(&attributes, Int16(flags))
        var noSignals = sigset_t()
        sigemptyset(&noSignals)
        posix_spawnattr_setsigmask(&attributes, &noSignals)
        var everySignal = sigset_t()
        sigfillset(&everySignal)
        posix_spawnattr_setsigdefault(&attributes, &everySignal)

        var files: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&files)
        defer { posix_spawn_file_actions_destroy(&files) }
        posix_spawn_file_actions_addopen(&files, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_addopen(&files, STDOUT_FILENO, log.path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
        posix_spawn_file_actions_adddup2(&files, STDOUT_FILENO, STDERR_FILENO)

        var pid: pid_t = 0
        let result = Self.withCStrings(arguments) { argv in
            Self.withCStrings(environmentStrings) { envp in
                posix_spawn(&pid, executable.path, &files, &attributes, argv, envp)
            }
        }
        guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: result) ?? .EINVAL) }
        return pid
    }

    /// Calls `body` with `strings` as a NULL-terminated C array, valid only during the call.
    private static func withCStrings<T>(_ strings: [String], _ body: ([UnsafeMutablePointer<CChar>?]) -> T) -> T {
        let pointers = strings.map { strdup($0) } + [nil]
        defer { pointers.forEach { free($0) } }
        return body(pointers)
    }
}
