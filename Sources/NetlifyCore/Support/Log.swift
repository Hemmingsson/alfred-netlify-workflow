import Foundation

/// Diagnostics: one line on stderr, which never reaches Alfred. A window command's stderr goes to `ui-errors.log`,
/// a background job's to `jobs.log`.
public enum Log {
    public static func write(_ line: String) {
        FileHandle.standardError.write(Data("netlify: \(line)\n".utf8))
    }
}
