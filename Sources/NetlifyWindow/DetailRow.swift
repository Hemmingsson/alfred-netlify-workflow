import NetlifyCore

/// One row of the detail pane: `<id>` (its value label), `<id>Row` (hidden when empty) and, when set, `<id>Icon`.
struct DetailRow: Equatable, Sendable {
    let id: String
    let text: String
    /// The value's colour, when it shows an exception.
    var colour: Colour?
    /// An SF Symbol replacing the row's icon.
    var icon: String?
    var tooltip: String?

    var changes: [String: ComponentChange] {
        var changes = [
            id: ComponentChange(text: SafeText(text), colour: colour, tooltip: tooltip.map { SafeText($0) }),
            id + "Row": ComponentChange(hidden: text.isEmpty),
        ]
        if let icon {
            changes[id + "Icon"] = ComponentChange(tint: colour == .label ? .tertiaryLabel : colour, image: .symbol(icon))
        }
        return changes
    }
}
