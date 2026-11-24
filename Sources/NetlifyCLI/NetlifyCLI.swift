import Foundation
import NetlifyCore

/// The `netlify` binary: parse the arguments, build the live `Context`, run the command.
public enum NetlifyCLI {
    /// Runs one command and returns the exit status. `ui` prints exactly one JSON action on stdout (`{}` at worst);
    /// diagnostics go to stderr. Background jobs print nothing on stdout. Unknown arguments: usage, exit 2.
    public static func run(arguments: [String], environment: [String: String]) async -> Int32 {
        guard let command = Command(arguments: arguments) else {
            if arguments.first == "ui" {
                // The window still gets its one line, so Alfred never shows a script error.
                Console.standard.output(Data("{}\n".utf8))
                Console.standard.diagnostic("unknown window command: \(arguments.dropFirst().joined(separator: " "))")
                return 0
            }
            FileHandle.standardError.write(Data((Command.usage + "\n").utf8))
            return 2
        }
        let context = Context.live(environment: environment, executable: executableURL)
        return await CommandRunner.live(context: context).run(command)
    }

    /// This binary, with symlinks resolved: its folder is the workflow folder, and jobs start it again.
    static var executableURL: URL {
        let url = Bundle.main.executableURL ?? URL(filePath: CommandLine.arguments[0])
        return url.resolvingSymlinksInPath()
    }
}
