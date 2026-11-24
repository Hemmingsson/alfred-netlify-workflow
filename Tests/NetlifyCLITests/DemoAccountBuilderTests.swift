@testable import demo
import Foundation
import NetlifyCore
import NetlifyTesting
import Testing

@Suite("The demo tool")
struct DemoAccountBuilderTests {
    /// Records the pictures the builder hands over instead of converting them.
    final class RecordingPictures: DemoPictures {
        var adopted: [(site: String, screenshot: URL?, favicon: URL?)] = []
        func adoptDemoPictures(screenshot: URL?, favicon: URL?, for site: Site) throws {
            adopted.append((site.id, screenshot, favicon))
        }
    }

    /// The repository, from this file's place in Tests/NetlifyCLITests.
    static let repository = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func builder(_ pictures: RecordingPictures) -> DemoAccountBuilder {
        DemoAccountBuilder(
            sources: Self.repository.appending(path: "demo", directoryHint: .isDirectory),
            workflowFolder: Self.repository.appending(path: "workflow", directoryHint: .isDirectory),
            now: Fixtures.now,
            makePictures: { _ in pictures }
        )
    }

    private func scratchFolder() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "netlify demo \(UUID().uuidString)/account", directoryHint: .isDirectory)
    }

    @Test func writesEveryDemoSiteNewestFirstWithItsPictures() throws {
        let folder = scratchFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let pictures = RecordingPictures()

        let sites = try builder(pictures).build(into: folder)

        let cached = try #require(SiteCache(paths: Paths(cacheFolder: folder, workflowFolder: folder, demoFolder: folder)).read())
        // The cache keeps whole seconds, so compare what was written by id.
        #expect(cached.sites.map(\.id) == sites.map(\.id))
        #expect(cached.savedAt == Fixtures.now)
        #expect(sites.count == DemoSite.catalogue.count)
        #expect(Set(sites.map(\.id)).count == sites.count)
        let published = sites.compactMap { $0.publishedDeploy?.publishedAt }
        #expect(published.count == sites.count)
        #expect(published == published.sorted(by: >))
        #expect(pictures.adopted.map(\.site) == sites.map(\.id))
        #expect(pictures.adopted.allSatisfy { $0.screenshot.map { FileManager.default.fileExists(atPath: $0.path) } == true })
        #expect(pictures.adopted.first?.favicon?.lastPathComponent == "blandband.svg")
    }

    @Test func demoSitesShowTheirExceptions() throws {
        let folder = scratchFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let sites = try builder(RecordingPictures()).build(into: folder)

        let selected = try #require(sites.first)
        #expect(selected.name == "blandband")
        #expect(selected.newestDeploy?.state == "building")
        #expect(selected.newestDeploy?.id != selected.publishedDeploy?.id)
        #expect(selected.publishedDeploy?.state == "ready")
        #expect(selected.newestDeploy?.publishedAt == nil)
        let padgrid = try #require(sites.first { $0.name == "padgrid" })
        #expect(padgrid.newestDeploy == nil)
        let switchboard = try #require(sites.first { $0.name == "switchboard" })
        #expect(switchboard.newestDeploy?.state == "error")
        #expect(switchboard.newestDeploy?.errorMessage == "Build script returned non-zero exit code: 2")
        #expect(sites.first { $0.name == "harbourmag" }?.publishedDeploy?.isLocked == true)
    }

    @Test func aRealSiteKeepsItsPunycodeDomain() throws {
        let folder = scratchFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let sites = try builder(RecordingPictures()).build(into: folder)
        #expect(sites.first { $0.name == "sapo-band" }?.customDomain == "xn--spo-qla.com")
    }

    @Test func refusesToReplaceAFolderThatIsNotADemo() throws {
        let folder = scratchFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("keep me".utf8).write(to: folder.appending(path: "notes.txt"))

        #expect(throws: DemoBuildError.notADemoFolder(folder)) {
            try builder(RecordingPictures()).build(into: folder)
        }
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: "notes.txt").path))
    }

    @Test func rebuildingReplacesAnEarlierDemo() throws {
        let folder = scratchFolder()
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        try builder(RecordingPictures()).build(into: folder)
        try Data().write(to: folder.appending(path: "stale.png"))

        try builder(RecordingPictures()).build(into: folder)
        #expect(!FileManager.default.fileExists(atPath: folder.appending(path: "stale.png").path))
    }
}
