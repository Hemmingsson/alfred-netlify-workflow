import Foundation
@testable import NetlifyCLI
import NetlifyCore
import NetlifyTesting
import NetlifyWindow
import Testing

@Suite("Running a command")
struct CommandRunnerTests {
    /// Records the jobs it was asked to run.
    final class RecordingJobs: Sendable {
        let ran = Locked<[BackgroundJob]>([])
    }

    /// Collects what the runner writes.
    final class Captured: Sendable {
        let output = Locked(Data())
        let diagnostics = Locked<[String]>([])
        var console: Console {
            Console(output: { data in self.output.withLock { $0.append(data) } }, diagnostic: { line in self.diagnostics.withLock { $0.append(line) } })
        }
        var stdout: String { String(decoding: output.value, as: UTF8.self) }
    }

    private func runner(_ test: TestContext, reply: WindowReply = .nothing, jobs: RecordingJobs = RecordingJobs(), captured: Captured) -> CommandRunner {
        CommandRunner(
            context: test.context,
            replyToWindow: { _ in reply },
            runJob: { job in jobs.ran.withLock { $0.append(job) } },
            console: captured.console
        )
    }

    @Test func aWindowCommandPrintsExactlyOneLineOfJSON() async throws {
        let test = TestContext()
        let captured = Captured()
        let reply = WindowReply(variables: ["status": SafeText("Fix {var:token}")])
        let status = await runner(test, reply: reply, captured: captured).run(.ui(.load(query: "")))
        #expect(status == 0)
        #expect(captured.stdout == String(decoding: try reply.json(), as: UTF8.self) + "\n")
        #expect(captured.stdout.filter { $0 == "\n" }.count == 1)
    }

    @Test func nothingToSayPrintsAnEmptyObject() async {
        let captured = Captured()
        _ = await runner(TestContext(), captured: captured).run(.ui(.load(query: "")))
        #expect(captured.stdout == "{}\n")
    }

    @Test func aJobRunsAndPrintsNothingOnStdout() async {
        let test = TestContext()
        let captured = Captured()
        let jobs = RecordingJobs()
        let status = await runner(test, jobs: jobs, captured: captured).run(.job(.refresh))
        #expect(status == 0)
        #expect(jobs.ran.value == [.refresh])
        #expect(captured.output.value.isEmpty)
        #expect(captured.diagnostics.value.count == 2)
    }

    @Test func demoModeRunsNoJobs() async {
        let jobs = RecordingJobs()
        _ = await runner(TestContext(demo: true), jobs: jobs, captured: Captured()).run(.job(.refresh))
        #expect(jobs.ran.value.isEmpty)
    }

    @Test func aRefusedActionExitsWithOneAndSaysWhy() async {
        let test = TestContext()
        let captured = Captured()
        let status = await runner(test, captured: captured).run(.action(.open(URL(string: "file:///etc/hosts")!)))
        #expect(status == 1)
        #expect(test.system.calls.isEmpty)
        #expect(captured.diagnostics.value.count == 1)
        #expect(captured.output.value.isEmpty)
    }

    @Test func aCopyPrintsTheTextForAlfredsNotification() async {
        let test = TestContext()
        let captured = Captured()
        let status = await runner(test, captured: captured).run(.action(.copy("https://bland.band")))
        #expect(status == 0)
        #expect(test.system.calls == [.copied("https://bland.band")])
        #expect(captured.stdout == "Copied https://bland.band")
    }

    @Test func openingPrintsNothingSoAlfredShowsNoNotification() async {
        let test = TestContext()
        let captured = Captured()
        let status = await runner(test, captured: captured).run(.action(.open(URL(string: "https://bland.band")!)))
        #expect(status == 0)
        #expect(captured.stdout.isEmpty)
    }
}
