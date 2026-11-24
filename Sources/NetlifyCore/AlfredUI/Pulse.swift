/// The `pulse` setting: how often the window runs `scripts/ui pulse …` to ask for news.
public struct Pulse: Encodable, Hashable, Sendable {
    /// Seconds between pulses; 0 stops them.
    public var interval: Double

    public init(interval: Double) {
        self.interval = interval
    }

    public static let stop = Pulse(interval: 0)
}
