// The `netlify` binary in the workflow folder. Everything is in NetlifyCLI, so tests can reach it.
import Foundation
import NetlifyCLI

let status = await NetlifyCLI.run(arguments: Array(CommandLine.arguments.dropFirst()), environment: ProcessInfo.processInfo.environment)
exit(status)
