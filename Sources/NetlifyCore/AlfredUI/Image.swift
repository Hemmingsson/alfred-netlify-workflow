import Foundation

/// What an image view or button shows.
public enum Image: Encodable, Hashable, Sendable {
    /// A picture file.
    case file(URL)
    /// An SF Symbol by name, e.g. `globe`.
    case symbol(String)
    /// No image: clears what was there (encodes as `null`).
    case empty

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .file(let url): try container.encode(["type": SafeText("file"), "src": SafeText(url.path)])
        case .symbol(let name): try container.encode(["type": "symbol", "src": name])
        case .empty: try container.encodeNil()
        }
    }
}
