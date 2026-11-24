import Foundation

/// How the app reads and writes JSON: the small files in the cache folder (`sites.json`, `sign-in.json`, a deploy's
/// `framing.json`, …) and Netlify's answers. Dates are ISO 8601, read with or without fractions of a second (Netlify
/// sends both).
public enum JSON {
    /// The value in `file`, or nil when the file is missing or doesn't decode.
    public static func read<Value: Decodable>(_ type: Value.Type, from file: URL) -> Value? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    /// Replace `file` with `value`, creating its folder. Atomic, so a reader never sees half a file.
    public static func write(_ value: some Encodable, to file: URL) throws {
        let data = try encoder.encode(value)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
    }

    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(text, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true)) {
                return date
            }
            if let date = try? Date(text, strategy: .iso8601) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not an ISO 8601 date: \(text)"))
        }
        return decoder
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
