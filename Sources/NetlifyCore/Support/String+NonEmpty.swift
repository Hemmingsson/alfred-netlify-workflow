extension String {
    /// The text, or nil when it is empty: Netlify and the demo files often write `""` for "none".
    public var nonEmpty: String? { isEmpty ? nil : self }
}

extension Optional<String> {
    /// The text, or nil when it is missing or empty.
    public var nonEmpty: String? { self?.nonEmpty }
}
