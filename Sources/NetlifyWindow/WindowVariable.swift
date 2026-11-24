/// Window variables (ui.json `variablesconfig`) that replies set and commands get back.
enum WindowVariable {
    static let fingerprint = "fingerprint"
    static let selectedSiteID = "selectedSiteID"
    static let previewSource = "previewSource"
    /// The window command the empty state's purple button sends (`EmptyAction.command`).
    static let emptyAction = "emptyAction"
}
