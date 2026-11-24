/// Keys of a row's hidden values, read by ui.json as `{data:<key>}` or `{value:sites.selected.<key>}`.
enum RowValue {
    static let match = "match"
    static let openSite = "openSite"
    static let openProject = "openProject"
    static let openDeploys = "openDeploys"
    static let copyURL = "copyURL"
    /// The detail pane's changes, applied with `update` on selection.
    static let detail = "detail"
}
