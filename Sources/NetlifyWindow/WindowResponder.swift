import Foundation
import NetlifyCore

/// Answers the window: one `WindowReply` per `WindowCommand`. Never throws; problems become text in the window.
/// Only `refresh` (⌘R) waits for the network. Every other command reads the cache folder and starts background jobs.
public struct WindowResponder: Sendable {
    let context: Context
    let refresher: any SiteRefresher
    let pictures: any PictureLibrary
    /// Dates in the window are local time.
    let timeZone: TimeZone

    public init(context: Context, refresher: any SiteRefresher, pictures: any PictureLibrary) {
        self.init(context: context, refresher: refresher, pictures: pictures, timeZone: .current)
    }

    init(context: Context, refresher: any SiteRefresher, pictures: any PictureLibrary, timeZone: TimeZone) {
        self.context = context
        self.refresher = refresher
        self.pictures = pictures
        self.timeZone = timeZone
    }

    /// Seconds between pulses while something loads, and otherwise (so "updated …" moves).
    static let busyPulse = Pulse(interval: 1.5)
    static let idlePulse = Pulse(interval: 30)

    public func reply(to command: WindowCommand) async -> WindowReply {
        switch command {
        case .load(let query):
            let snapshot = snapshot(refresh: .whenStale)
            if let cached = snapshot.sites {
                presenter.previews.tidy(keeping: cached.sites.map(\.id))
            }
            return windowReply(snapshot, selectedSiteID: "", previewSource: nil, previousFingerprint: nil, query: query)

        case .pulse(let fingerprint, let selected, let preview):
            return windowReply(snapshot(refresh: .whenStaleWithoutProblem), selectedSiteID: selected, previewSource: preview, previousFingerprint: fingerprint)

        case .refresh(let selected, let preview, let query):
            if !isDemo && context.isSignedIn {
                await refresher.refresh()
            }
            return windowReply(snapshot(refresh: .never), selectedSiteID: selected, previewSource: preview, previousFingerprint: "", query: query)

        case .selected(let siteID, let previewSource):
            return selected(siteID: siteID, previewSource: previewSource)

        case .filtered(let selected, let query):
            // The filter hid every row: the detail pane hides too, next to "No matching sites".
            let hidden = selected.isEmpty || (!SearchQuery(query).isEmpty && visibleSites(cache.read()?.sites ?? [], query: query).isEmpty)
            return WindowReply(update: [ComponentID.detailPane: ComponentChange(hidden: hidden)])

        case .finish(let argument):
            guard FinishArgument(argument: argument) != nil else { return .nothing }
            return WindowReply(finish: SafeText(argument))

        case .signIn:
            if !isDemo {
                let attempt = UUID().uuidString
                try? SignInProgress(attempt: attempt, stage: .connecting, updatedAt: context.now()).write(paths: context.paths)
                context.jobs.launch(.signIn(attempt: attempt))
            }
            return windowReply(snapshot(refresh: .never), selectedSiteID: "", previewSource: nil, previousFingerprint: "")

        case .cancelSignIn:
            SignInProgress.clear(paths: context.paths)
            return windowReply(snapshot(refresh: .never), selectedSiteID: "", previewSource: nil, previousFingerprint: "")

        case .retry:
            if !isDemo && context.isSignedIn && !JobLock(.refresh, paths: context.paths).isHeld {
                context.jobs.launch(.refresh)
            }
            var snapshot = snapshot(refresh: .never)
            if snapshot.sites == nil, case .empty(.failed) = snapshot.content {
                snapshot = WindowSnapshot(content: .empty(.loading), isRefreshing: true, picturesLoading: false)
            }
            return windowReply(snapshot, selectedSiteID: "", previewSource: nil, previousFingerprint: "")

        case .signOut:
            return signOut()
        }
    }

    /// When reading the window's state may start a background refresh of a stale or missing cache.
    private enum RefreshPolicy: Sendable {
        /// The window opened: refresh when stale, even after a failure (opening again is how a user retries).
        case whenStale
        /// A pulse: refresh when stale, unless the last refresh failed (no retry loop; Retry and ⌘R are the way).
        case whenStaleWithoutProblem
        /// A refresh just ran.
        case never
    }

    // MARK: Parts

    private var isDemo: Bool { context.settings.isDemo }
    private var cache: SiteCache { SiteCache(paths: context.paths) }
    private var text: TextFormatter { TextFormatter(now: context.now(), timeZone: timeZone) }
    private var presenter: SitePresenter { SitePresenter(text: text, pictures: pictures, paths: context.paths) }

    /// Read the window's state; start a refresh when `policy` allows and the cache is missing or stale, and start
    /// fetching missing pictures. Nothing here waits for the network.
    private func snapshot(refresh policy: RefreshPolicy) -> WindowSnapshot {
        let signIn = isDemo ? nil : signInProgress()
        if signIn?.stage == .connecting {
            return WindowSnapshot(content: .empty(.connecting), isRefreshing: false, picturesLoading: false)
        }
        let signInFailure = signIn?.stage == .failed ? signIn?.message : nil
        guard context.isSignedIn else {
            return WindowSnapshot(content: .empty(signInFailure.map(EmptyState.signInFailed) ?? .signedOut), isRefreshing: false, picturesLoading: false)
        }
        let problem = isDemo ? nil : cache.readProblem()
        if problem == .signInRejected {
            return WindowSnapshot(content: .empty(signInFailure.map(EmptyState.signInFailed) ?? .signInRejected), isRefreshing: false, picturesLoading: false)
        }
        let failure: String? = if case .failed(let message) = problem { message } else { nil }
        let cached = cache.read()
        var refreshing = !isDemo && JobLock(.refresh, paths: context.paths).isHeld
        let stale = cached.map { $0.age(at: context.now()) > context.settings.refreshAfter } ?? true
        let allowed = switch policy {
        case .whenStale: true
        case .whenStaleWithoutProblem: problem == nil
        case .never: false
        }
        if !isDemo, !refreshing, stale, allowed {
            context.jobs.launch(.refresh)
            refreshing = true
        }
        guard let cached else {
            if let failure, !refreshing {
                return WindowSnapshot(content: .empty(.failed(failure)), refreshFailure: failure, isRefreshing: false, picturesLoading: false)
            }
            return WindowSnapshot(content: .empty(.loading), isRefreshing: refreshing, picturesLoading: false)
        }
        let loading = !isDemo && pictures.startPicturesJobIfNeeded(for: cached.sites)
        return WindowSnapshot(content: .sites(cached), refreshFailure: failure, isRefreshing: refreshing, picturesLoading: loading)
    }

    /// The recorded sign-in, if it still means something: a `connecting` file counts only while the job holds its
    /// lock, or for a moment after launching it (a crashed job leaves it behind).
    private func signInProgress() -> SignInProgress? {
        guard let progress = SignInProgress.read(paths: context.paths) else { return nil }
        if progress.stage == .connecting,
           !JobLock(.signIn(attempt: nil), paths: context.paths).isHeld,
           context.now().timeIntervalSince(progress.updatedAt) > SignInProgress.startGrace {
            return nil
        }
        return progress
    }

    /// Forget the token and everything cached for the account, then show the signed-out window. A failure says so
    /// in the window: the user would otherwise think they had signed out.
    private func signOut() -> WindowReply {
        guard !isDemo else { return .nothing }
        SignInProgress.clear(paths: context.paths)
        do {
            try context.paths.forgetAccount { try context.tokens.delete() }
        } catch {
            let state = EmptyState.signOutFailed(error.localizedDescription)
            return emptyReply(state, isRefreshing: false)
        }
        return windowReply(snapshot(refresh: .never), selectedSiteID: "", previewSource: nil, previousFingerprint: "")
    }

    /// A row was selected: swap in its live preview when the preview holds another page (a list update re-selects
    /// the same row, which must not reload the page), and start its render.
    private func selected(siteID: String, previewSource: String) -> WindowReply {
        guard let site = cache.site(id: siteID) else { return .nothing }
        var reply = WindowReply.nothing
        let preview = presenter.livePreview(for: site)
        if preview.source != previewSource {
            reply.replace = [ComponentID.livePreview: preview.component]
            reply.variables = [WindowVariable.previewSource: SafeText(preview.source)]
        }
        if !isDemo, site.isPublished, site.url != nil, pictures.startRenderJobIfNeeded(site) {
            reply.pulse = Self.busyPulse
        }
        return reply
    }

    /// The sites the search field's text leaves in the list (all of them for no text). Errs towards more sites
    /// than Alfred shows, never fewer.
    private func visibleSites(_ sites: [Site], query: String) -> [Site] {
        let search = SearchQuery(query)
        guard !search.isEmpty else { return sites }
        return sites.filter { search.matches(SiteSummary($0).searchText) }
    }

    // MARK: Replies

    /// Everything the window shows. With `previousFingerprint` equal to the list's, only the status line (the list
    /// didn't change; ages alone don't resend it). `previewSource` nil (opening) always loads the live preview;
    /// otherwise it is replaced only when it changed, so a refresh keeps the page in the preview.
    /// `query` (opening and ⌘R) is the search text: when it hides every row, the detail pane stays hidden.
    private func windowReply(_ snapshot: WindowSnapshot, selectedSiteID: String, previewSource: String?, previousFingerprint: String?, query: String? = nil) -> WindowReply {
        guard let cached = snapshot.sites else {
            guard case .empty(let state) = snapshot.content else { return .nothing }
            return emptyReply(state, isRefreshing: snapshot.isRefreshing)
        }
        let fingerprint = listFingerprint(cached.sites)
        let pulse = pulse(for: snapshot)
        let statusChange = statusLine(cached, snapshot)
        if previousFingerprint == fingerprint {
            return WindowReply(update: [ComponentID.statusLabel: statusChange], pulse: pulse)
        }

        let presenter = presenter
        let visible = query.map { visibleSites(cached.sites, query: $0) } ?? cached.sites
        let chosen = visible.first { $0.id == selectedSiteID } ?? visible.first
        var variables: [String: SafeText] = [WindowVariable.fingerprint: SafeText(fingerprint)]
        var update: [String: ComponentChange] = [
            ComponentID.sites: ComponentChange(
                placeholder: "No matching sites",
                data: DataSource(rows: cached.sites.map(presenter.row), filter: Self.filter)
            ),
            ComponentID.statusLabel: statusChange,
            ComponentID.mainContent: ComponentChange(hidden: false),
            ComponentID.emptyPane: ComponentChange(hidden: true),
        ]
        var replace: [String: Component]?
        if let chosen {
            if chosen.id != selectedSiteID { variables[WindowVariable.selectedSiteID] = SafeText(chosen.id) }
            var detail = presenter.detail(for: chosen)
            // A list update keeps the pane as the filter left it; only coming from an empty list shows it.
            if previousFingerprint?.hasPrefix(Self.listPrefix) == true { detail[ComponentID.detailPane] = nil }
            update.merge(detail) { _, new in new }
            let preview = presenter.livePreview(for: chosen)
            if preview.source != previewSource {
                replace = [ComponentID.livePreview: preview.component]
                variables[WindowVariable.previewSource] = SafeText(preview.source)
            }
        } else {
            variables[WindowVariable.selectedSiteID] = ""
            update[ComponentID.detailPane] = ComponentChange(hidden: true)
        }
        return WindowReply(variables: variables, update: update, replace: replace, functions: [ComponentID.sites: "filterdata"], pulse: pulse)
    }

    /// Nothing to list: the list and the detail pane are hidden, and a message is centred in the window with the
    /// button that helps (Sign in or Retry), or Try again and Cancel while connecting.
    private func emptyReply(_ state: EmptyState, isRefreshing: Bool) -> WindowReply {
        let action = state.action
        return WindowReply(
            variables: [
                WindowVariable.fingerprint: SafeText(Self.emptyPrefix + Fingerprint.of(state.title + "\n" + state.detail)),
                WindowVariable.selectedSiteID: "",
                WindowVariable.previewSource: SafeText(LivePreview.hidden.source),
                WindowVariable.emptyAction: SafeText(action?.command ?? ""),
            ],
            update: [
                ComponentID.mainContent: ComponentChange(hidden: true),
                ComponentID.emptyPane: ComponentChange(hidden: false),
                ComponentID.emptyTitle: ComponentChange(text: SafeText(state.title)),
                ComponentID.emptyDetail: ComponentChange(text: SafeText(state.detail), hidden: state.detail.isEmpty),
                ComponentID.emptyActionBox: ComponentChange(hidden: action == nil),
                ComponentID.emptyActionButton: ComponentChange(text: SafeText(action?.title ?? ""), tooltip: SafeText(action?.tooltip ?? "")),
                ComponentID.connectingButtons: ComponentChange(hidden: !state.offersCancel),
                ComponentID.sites: ComponentChange(data: DataSource(rows: [], filter: Self.filter)),
                ComponentID.statusLabel: ComponentChange(text: "", tooltip: ""),
                ComponentID.detailPane: ComponentChange(hidden: true),
            ],
            replace: [ComponentID.livePreview: LivePreview.hidden.component],
            pulse: state.isBusy || isRefreshing ? Self.busyPulse : .stop
        )
    }

    /// "N sites · updated 7 min ago", "Refreshing…", or "Refresh failed · updated 20 min ago" (the reason in the
    /// tooltip), plus " · loading previews…" while pictures are coming.
    private func statusLine(_ cached: CachedSites, _ snapshot: WindowSnapshot) -> ComponentChange {
        if snapshot.isRefreshing { return ComponentChange(text: "Refreshing…", tooltip: "") }
        let updated = "updated \(text.ago(cached.savedAt))"
        let head = snapshot.refreshFailure == nil ? TextFormatter.plural(cached.sites.count, "site") : "Refresh failed"
        let tail = snapshot.picturesLoading ? " · loading previews…" : ""
        return ComponentChange(text: SafeText("\(head) · \(updated)\(tail)"), tooltip: SafeText(snapshot.refreshFailure ?? ""))
    }

    private func pulse(for snapshot: WindowSnapshot) -> Pulse {
        snapshot.isRefreshing || snapshot.picturesLoading ? Self.busyPulse : Self.idlePulse
    }

    /// Changes when anything the list or the detail pane shows changes, except the passing of time: made from the
    /// sites and their pictures, not from the rows (whose ages change by themselves).
    private func listFingerprint(_ sites: [Site]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .secondsSince1970
        var data = (try? encoder.encode(sites)) ?? Data()
        for site in sites {
            let facts = [pictures.thumbnail(for: site)?.path, pictures.picture(for: site)?.path, pictures.favicon(for: site)?.path,
                         pictures.allowsFraming(site).map { $0 ? "frame" : "no-frame" }]
            data.append(Data(facts.map { $0 ?? "-" }.joined(separator: "\n").utf8))
        }
        return Self.listPrefix + Fingerprint.of(data)
    }

    /// Fingerprints say whether they describe a list or an empty state.
    static let listPrefix = "l"
    static let emptyPrefix = "e"

    /// Search: the field's words against each row's `match`, in any order. Sent with every list update, because
    /// replacing a dataview's data replaces its filter too.
    static let filter = DataFilter(field: RowValue.match, match: .value("searchField.text"))
}
