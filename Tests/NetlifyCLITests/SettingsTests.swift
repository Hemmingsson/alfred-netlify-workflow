import Foundation
import NetlifyCore
import Testing

@Suite("Settings and folders from Alfred's environment")
struct SettingsTests {
    @Test(arguments: [
        ("2", 120.0), (" 10 ", 600.0), ("0.5", 30.0),
        ("", 300.0), ("   ", 300.0), ("soon", 300.0), ("0", 300.0), ("-3", 300.0), ("inf", 300.0), ("nan", 300.0),
    ])
    func refreshAfterIsAPositiveNumberElseFive(text: String, seconds: Double) {
        #expect(Settings(environment: ["cache_minutes": text]).refreshAfter == seconds)
    }

    @Test func refreshAfterDefaultsToFiveMinutes() {
        #expect(Settings(environment: [:]).refreshAfter == 300)
    }

    @Test func demoModeComesFromNetlifyDemo() {
        let settings = Settings(environment: ["netlify_demo": "/tmp/demo sites"])
        #expect(settings.isDemo)
        #expect(settings.demoFolder?.path == "/tmp/demo sites")
    }

    @Test func theCacheFolderIsAlfredsWhenGiven() {
        let environment = ["alfred_workflow_cache": "/tmp/Workflow Data/x", "HOME": "/Users/someone"]
        let paths = Paths(environment: environment, settings: Settings(environment: environment), workflowFolder: URL(filePath: "/w"))
        #expect(paths.cacheFolder.path == "/tmp/Workflow Data/x")
    }

    @Test func withoutAlfredTheCacheFolderIsAlfredsUsualPlaceUnderHome() {
        let environment = ["HOME": "/Users/someone"]
        let paths = Paths(environment: environment, settings: Settings(environment: environment), workflowFolder: URL(filePath: "/w"))
        #expect(paths.cacheFolder.path == "/Users/someone/Library/Caches/com.runningwithcrayons.Alfred/Workflow Data/work.mattias.alfred.netlify")
    }
}
