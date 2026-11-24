import Foundation
import NetlifyAPI
import NetlifyCore
import NetlifyPictures
import NetlifyWindow

/// Runs one parsed `Command` against a `Context`. The window's replies and the jobs are closures, so tests can
/// swap them.
struct CommandRunner: Sendable {
    let context: Context
    /// Answers a window command.
    let replyToWindow: @Sendable (WindowCommand) async -> WindowReply
    /// Does a background job's work in this process. Each job holds its own `JobLock`.
    let runJob: @Sendable (BackgroundJob) async -> Void
    let console: Console

    /// The real window and jobs, sharing one `RefreshJob`.
    static func live(context: Context, console: Console = .standard) -> CommandRunner {
        let refresher = RefreshJob(context: context, client: NetlifyClient(context: context))
        let window = WindowResponder(context: context, refresher: refresher, pictures: PictureStore(context: context))
        return CommandRunner(
            context: context,
            replyToWindow: { await window.reply(to: $0) },
            runJob: { job in
                switch job {
                case .refresh: await refresher.refresh()
                case .pictures: await PictureJobs(context: context).fetchMissing()
                case .render(let siteID): await PictureJobs(context: context).render(siteID: siteID)
                case .signIn(let attempt): await SignInJob(context: context, refresher: refresher, attempt: attempt).run()
                }
            },
            console: console
        )
    }

    /// Runs `command`; returns the exit status. `ui` always exits 0 so Alfred uses what it printed.
    func run(_ command: Command) async -> Int32 {
        switch command {
        case .ui(let windowCommand):
            await answer(windowCommand)
            return 0
        case .action(let argument):
            do {
                let message = try WorkflowActions(context: context).perform(argument)
                console.output(Data(message.utf8))
                return 0
            } catch {
                console.diagnostic("action \(argument.argument): \(error.localizedDescription)")
                return 1
            }
        case .job(let job):
            await runLogged(job)
            return 0
        }
    }

    /// Prints exactly one line of JSON: the reply, or `{}` when it can't be encoded.
    private func answer(_ command: WindowCommand) async {
        let reply = await replyToWindow(command)
        var json: Data
        do {
            json = try reply.json()
        } catch {
            console.diagnostic("ui \(command.arguments.joined(separator: " ")): could not encode the reply: \(error)")
            json = Data("{}".utf8)
        }
        json.append(UInt8(ascii: "\n"))
        console.output(json)
    }

    /// Runs a job and logs its start and end. In demo mode nothing is fetched, so jobs don't run at all.
    private func runLogged(_ job: BackgroundJob) async {
        let name = job.arguments.joined(separator: " ")
        guard !context.settings.isDemo else {
            console.diagnostic("\(name): skipped in demo mode")
            return
        }
        let started = context.now()
        console.diagnostic("\(started.formatted(.iso8601)) \(name): started")
        await runJob(job)
        let seconds = context.now().timeIntervalSince(started)
        console.diagnostic("\(context.now().formatted(.iso8601)) \(name): finished in \(seconds.formatted(.number.precision(.fractionLength(1)))) s")
    }
}
