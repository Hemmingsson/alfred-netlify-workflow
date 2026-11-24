import Foundation
import NetlifyCore
import Testing

@Suite("Argument formats read back what they write")
struct ArgumentTests {
    @Test(arguments: [BackgroundJob.refresh, .pictures, .render(siteID: "s1"), .signIn(attempt: nil), .signIn(attempt: "a1")])
    func backgroundJobs(job: BackgroundJob) {
        #expect(BackgroundJob(arguments: job.arguments) == job)
    }

    @Test func unknownJobs() {
        #expect(BackgroundJob(arguments: ["render"]) == nil)
        #expect(BackgroundJob(arguments: ["sing-in"]) == nil)
    }

    @Test(arguments: [
        FinishArgument.open(URL(string: "https://bland.band/?a=1&b=2")!),
        .copy("https://bland.band"),
    ])
    func finishArguments(argument: FinishArgument) {
        #expect(FinishArgument(argument: argument.argument) == argument)
    }

    @Test func aDefusedFinishArgumentIsRestored() {
        let sent = SafeText.defuse(FinishArgument.copy("https://x.test/{var:token}").argument)
        #expect(FinishArgument(argument: sent) == .copy("https://x.test/{var:token}"))
    }

    @Test func settingsComeFromTheEnvironment() {
        let settings = Settings(environment: ["cache_minutes": "2", "netlify_demo": ""])
        #expect(settings.refreshAfter == 120)
        #expect(!settings.isDemo)
        #expect(settings.bundleID == Settings.defaultBundleID)
    }
}
