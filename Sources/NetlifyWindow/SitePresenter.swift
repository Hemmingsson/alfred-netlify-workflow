import Foundation
import NetlifyCore

/// Turns a site into what the window shows: its list row, the detail pane for it, and its live preview.
/// Only reads files (pictures) and writes the site's preview page; never the network.
struct SitePresenter: Sendable {
    let text: TextFormatter
    let pictures: any PictureLibrary
    let paths: Paths
    var previews: PreviewPages { PreviewPages(paths: paths) }

    // MARK: Row

    /// The list row, with the hidden values the actions and the detail pane read.
    func row(for site: Site) -> DataRow {
        let summary = SiteSummary(site)
        let state = SiteState(site)
        let published = site.publishedDeploy.map { $0.publishedAt ?? $0.createdAt }
        return DataRow(
            uid: SafeText(site.id),
            cells: [
                ComponentID.rowThumbnail: ComponentChange(image: .file(pictures.thumbnail(for: site) ?? paths.workflowIcon)),
                ComponentID.rowTitle: ComponentChange(text: SafeText(summary.host)),
                ComponentID.rowSubtitle: ComponentChange(text: SafeText(summary.repositoryName ?? site.name)),
                ComponentID.rowRepositoryIcon: ComponentChange(image: sourceIcon(site)),
                ComponentID.rowAge: ComponentChange(text: SafeText(published.map(text.ago) ?? "")),
                ComponentID.rowState: ComponentChange(text: SafeText(state.label ?? ""), colour: state.colour),
            ],
            values: [
                RowValue.match: .text(SafeText(summary.searchText)),
                RowValue.openSite: .text(SafeText(FinishArgument.open(summary.siteURL).argument)),
                RowValue.openProject: .text(SafeText(FinishArgument.open(summary.adminURL).argument)),
                RowValue.openDeploys: .text(SafeText(FinishArgument.open(summary.deploysURL).argument)),
                RowValue.copyURL: .text(SafeText(FinishArgument.copy(summary.siteURL.absoluteString).argument)),
                RowValue.detail: .changes(detail(for: site)),
            ]
        )
    }

    /// The GitHub mark, a branch for other git providers, a box without a repository.
    private func sourceIcon(_ site: Site) -> Image {
        guard let repository = site.repository else { return .symbol("shippingbox") }
        return repository.isGitHub ? .file(paths.githubIcon) : .symbol("arrow.triangle.branch")
    }

    // MARK: Live preview

    /// The preview page when the live site may be shown: published, with a URL, framing known to be allowed, not demo.
    func livePreview(for site: Site) -> LivePreview {
        guard !paths.isDemo, site.isPublished, let url = site.url, pictures.allowsFraming(site) == true,
              let page = previews.page(siteID: site.id, url: url, picture: pictures.picture(for: site) ?? paths.workflowIcon)
        else { return .hidden }
        return LivePreview(source: page.path)
    }

    // MARK: Detail pane

    /// Every value of the detail pane for this site (an update keeps whatever the previous site set, so nothing is
    /// left out).
    func detail(for site: Site) -> [String: ComponentChange] {
        let summary = SiteSummary(site)
        var changes: [String: ComponentChange] = [
            ComponentID.detailPane: ComponentChange(hidden: false),
            // Never published: no picture; an old render could show a page the site no longer serves.
            ComponentID.pictureView: ComponentChange(image: site.isPublished && site.url != nil
                ? .file(pictures.picture(for: site) ?? paths.workflowIcon) : .empty),
            ComponentID.addressLabel: ComponentChange(text: SafeText(summary.displayURL)),
            ComponentID.addressIcon: ComponentChange(image: pictures.favicon(for: site).map(Image.file) ?? .symbol("globe")),
        ]
        for row in projectRows(site) + deployRows(site) {
            changes.merge(row.changes) { _, new in new }
        }
        return changes
    }

    /// PROJECT: the Netlify name (unless the row shows it already), the stack, other domains and warnings.
    func projectRows(_ site: Site) -> [DetailRow] {
        let summary = SiteSummary(site)
        let name: String
        if summary.repositoryName != nil {
            name = site.name
        } else if let deploy = site.publishedDeploy {
            name = SiteSummary.sourceText(deploy.source) ?? "Deployed by drag and drop"
        } else {
            name = "Nothing deployed"
        }
        var others = site.customDomain.nonEmpty == nil ? [] : [site.netlifyDomain]
        others += site.domainAliases.filter { !$0.isEmpty }
        others = others.map(Punycode.displayHost)
        let domains = others.first.map { others.count > 1 ? "\($0) +\(others.count - 1)" : $0 }
        let secure = site.url?.scheme == "https" || site.hasSSL
        return [
            DetailRow(id: "projectName", text: name),
            DetailRow(id: "projectStack", text: stackText(site)),
            DetailRow(id: "projectDomains", text: TextFormatter.joined([
                domains, secure ? nil : "HTTP only", site.hasPassword ? "Password protected" : nil,
            ])),
        ]
    }

    /// Framework, functions, edge functions and forms, e.g. "SvelteKit · 1 function"; "Static site" when empty.
    func stackText(_ site: Site) -> String {
        let deploy = site.publishedDeploy ?? site.newestDeploy
        var parts: [String?] = [FrameworkName.name(for: deploy?.framework)]
        if let deploy, deploy.functionCount > 0 {
            let scheduled = deploy.scheduledFunctionCount > 0 ? ", \(deploy.scheduledFunctionCount) scheduled" : ""
            parts.append(TextFormatter.plural(deploy.functionCount, "function") + scheduled)
        }
        if deploy?.hasEdgeFunctions == true { parts.append("edge functions") }
        if let forms = site.forms, forms.count > 0 {
            parts.append("\(TextFormatter.plural(forms.count, "form")), \(TextFormatter.plural(forms.submissions, "submission"))")
        } else if site.forms == nil && site.usesForms {
            parts.append("forms")
        }
        let text = TextFormatter.joined(parts)
        return text.isEmpty ? "Static site" : text
    }

    /// LATEST DEPLOY: what changed, who and when, where from. Every row describes one deploy: the newest when it
    /// failed or is building, else the live one. Exceptions replace the message, in colour.
    func deployRows(_ site: Site) -> [DetailRow] {
        let state = SiteState(site)
        guard let deploy = state.describedDeploy(of: site) else {
            return [
                DetailRow(id: "deployMessage", text: "Not published yet", colour: .secondaryLabel, icon: "exclamationmark.circle", tooltip: ""),
                DetailRow(id: "deployWho", text: ""),
                DetailRow(id: "deployRef", text: ""),
            ]
        }
        let title = SiteSummary.title(of: deploy)
        var message = DetailRow(id: "deployMessage", text: title, colour: .label, icon: "text.bubble", tooltip: deploy.title ?? title)
        switch state {
        case .failed:
            let error = TextFormatter.firstLine(deploy.errorMessage) ?? "Deploy failed"
            message = DetailRow(id: "deployMessage", text: "Failed \(text.ago(deploy.createdAt)): \(error)", colour: .red,
                                icon: "xmark.octagon", tooltip: deploy.errorMessage ?? message.tooltip)
        case .building:
            message = DetailRow(id: "deployMessage", text: "Building, started \(text.ago(deploy.createdAt))", colour: .orange,
                                icon: "hammer", tooltip: message.tooltip)
        case .locked:
            message = DetailRow(id: "deployMessage", text: "Locked: auto publishing stopped", colour: .yellow,
                                icon: "lock", tooltip: message.tooltip)
        case .notPublished, .published:
            break
        }
        let who = TextFormatter.joined([deploy.committer, text.longDate(deploy.publishedAt ?? deploy.createdAt)])
        let ref = site.repository == nil ? "" : TextFormatter.joined([deploy.branch, deploy.commitRef.map { String($0.prefix(7)) }])
        return [message, DetailRow(id: "deployWho", text: who), DetailRow(id: "deployRef", text: ref)]
    }
}
