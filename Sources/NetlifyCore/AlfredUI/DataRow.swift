/// One row of a dataview. Alfred wants it flat: `"<cellId>.<property>": value` for each cell component, plus hidden
/// values that actions read with `{data:<key>}` or `{value:<list>.selected.<key>}`.
public struct DataRow: Encodable, Equatable, Sendable {
    /// Stable id, so the selection survives updates.
    public var uid: SafeText
    /// Cell component id to its properties, e.g. `"rowTitle": ComponentChange(text: "bland.band")`.
    public var cells: [String: ComponentChange]
    /// Hidden values by key.
    public var values: [String: Value]

    /// A hidden value: text, or a set of component changes the window applies with `{var:…}` (the detail pane).
    public enum Value: Encodable, Equatable, Sendable {
        case text(SafeText)
        case changes([String: ComponentChange])

        public func encode(to encoder: any Encoder) throws {
            switch self {
            case .text(let text): try text.encode(to: encoder)
            case .changes(let changes): try changes.encode(to: encoder)
            }
        }
    }

    public init(uid: SafeText, cells: [String: ComponentChange], values: [String: Value] = [:]) {
        self.uid = uid
        self.cells = cells
        self.values = values
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(uid, forKey: DynamicKey("uid"))
        for (id, change) in cells {
            try change.encode(into: &container, prefix: id + ".")
        }
        for (key, value) in values {
            try container.encode(value, forKey: DynamicKey(key))
        }
    }
}
