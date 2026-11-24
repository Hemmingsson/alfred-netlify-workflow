import NetlifyCore
import NetlifyWindow

/// A run of the `netlify` binary, from its arguments.
public enum Command: Equatable, Sendable {
    /// `ui <command> …`: reply to the window (sites.alfredui/scripts/ui).
    case ui(WindowCommand)
    /// `action <argument>`: the window finished with this (the workflow's Run Script).
    case action(FinishArgument)
    /// `refresh`, `pictures`, `render <id>`, `sign-in`: a background job (started by `JobLauncher`).
    case job(BackgroundJob)

    public static let usage = """
        usage: netlify ui <command> [arguments…]   reply to the window with one JSON action
               netlify action <argument>            the window finished: open:<url>, copy:<text>
               netlify refresh | pictures | render <site id> | sign-in [attempt]   background jobs
        """

    /// The arguments that run this command; `init(arguments:)` reads them back.
    public var arguments: [String] {
        switch self {
        case .ui(let command): ["ui"] + command.arguments
        case .action(let argument): ["action", argument.argument]
        case .job(let job): job.arguments
        }
    }

    /// The command these arguments name, or nil (then print `usage` and exit 2).
    public init?(arguments: [String]) {
        guard let name = arguments.first else { return nil }
        let rest = Array(arguments.dropFirst())
        switch name {
        case "ui":
            guard let command = WindowCommand(arguments: rest) else { return nil }
            self = .ui(command)
        case "action":
            guard rest.count == 1, let argument = FinishArgument(argument: rest[0]) else { return nil }
            self = .action(argument)
        default:
            guard let job = BackgroundJob(arguments: arguments) else { return nil }
            self = .job(job)
        }
    }
}
