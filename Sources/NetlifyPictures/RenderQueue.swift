import Foundation
import NetlifyCore

/// Renders run one at a time, and only the newest selection waits: the queue holds a single site id, which each
/// request replaces. Whichever `render` job holds the renderer lock renders queued sites until none is left.
///
/// No request is lost: a job that finds the lock held exits, and the holder looks at the queue again after letting
/// go of the lock, so it sees any request made while it held it.
struct RenderQueue: Sendable {
    /// The one queued site id.
    let file: URL
    /// Held by the job that is rendering.
    let renderer: JobLock

    init(paths: Paths) {
        file = paths.picturesFolder.appending(path: "render-queue")
        renderer = JobLock(file: paths.locksFolder.appending(path: "renderer.lock"))
    }

    /// Queue `siteID`, replacing whatever was waiting.
    func request(_ siteID: String) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(siteID.utf8).write(to: file, options: .atomic)
    }

    var isEmpty: Bool { !FileManager.default.fileExists(atPath: file.path) }

    /// True while a job is rendering.
    var isRendering: Bool { renderer.isHeld }

    /// Become the renderer and `render` each queued site in turn; return at once when another job is the renderer.
    func drain(isolation: isolated (any Actor)? = #isolation, _ render: (String) async -> Void) async {
        repeat {
            let ranAsRenderer: Void? = await renderer.tryHolding {
                while let siteID = takeNext() {
                    await render(siteID)
                }
            }
            guard ranAsRenderer != nil else { return }
        } while !isEmpty
    }

    /// Remove and return the queued id. Moving the file away first means a request written meanwhile isn't lost.
    func takeNext() -> String? {
        let taken = file.deletingLastPathComponent().appending(path: "render-queue-\(UUID().uuidString)")
        guard (try? FileManager.default.moveItem(at: file, to: taken)) != nil else { return nil }
        defer { try? FileManager.default.removeItem(at: taken) }
        return (try? String(contentsOf: taken, encoding: .utf8))?.nonEmpty
    }
}
