/// A coding key made from any string, for JSON objects whose keys are data (component ids, `cell.property`).
struct DynamicKey: CodingKey {
    let stringValue: String

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    var intValue: Int? { nil }

    init?(intValue: Int) {
        nil
    }
}
