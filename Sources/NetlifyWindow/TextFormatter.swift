import Foundation

/// Times and counts as the window words them: "4 min ago", "Nov 18 at 17:00", "3 sites".
struct TextFormatter: Sendable {
    let now: Date
    let timeZone: TimeZone

    /// "just now", "4 min ago", "3 h ago", "12 d ago" (under 45 days), "2 mo ago", "1 y ago".
    func ago(_ date: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        let minute = 60.0, hour = 3600.0, day = 86400.0
        switch seconds {
        case ..<minute: return "just now"
        case ..<hour: return "\(Int(seconds / minute)) min ago"
        case ..<day: return "\(Int(seconds / hour)) h ago"
        case ..<(45 * day): return "\(Int(seconds / day)) d ago"
        case ..<(365 * day): return "\(max(1, Int((seconds / (30 * day)).rounded()))) mo ago"
        default: return "\(max(1, Int((seconds / (365 * day)).rounded()))) y ago"
        }
    }

    /// "Nov 18 at 17:00" in local time, with the year ("Nov 18, 2025 at 17:00") when it isn't this year.
    func longDate(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = sameYear ? "MMM d 'at' HH:mm" : "MMM d, yyyy 'at' HH:mm"
        return formatter.string(from: date)
    }

    /// "1 site", "3 sites".
    static func plural(_ count: Int, _ word: String) -> String {
        "\(count) \(word)\(count == 1 ? "" : "s")"
    }

    /// The non-empty parts joined with " · ".
    static func joined(_ parts: [String?]) -> String {
        parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// The first non-empty line of `text`, trimmed.
    static func firstLine(_ text: String?) -> String? {
        text?.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }
}
