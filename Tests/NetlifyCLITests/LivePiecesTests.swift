import Foundation
@testable import NetlifyCLI
import NetlifyCore
import Testing

@Suite("Live pieces that run offline")
struct LivePiecesTests {
    @Test func aDetachedJobRunsInItsOwnSessionWithItsOutputInTheLog() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "netlify job \(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        // A stand-in for the binary: prints its arguments, an environment variable, whether stdin is empty, and
        // whether it leads its own session (its process group is its own pid), then writes to stderr.
        let executable = folder.appending(path: "fake netlify")
        try """
        #!/bin/sh
        echo "args: $*"
        echo "setting: $alfred_workflow_cache"
        echo "stdin: $(cat | wc -c | tr -d ' ')"
        [ "$(ps -o pgid= -p $$ | tr -d ' ')" = "$$" ] && echo "own session"
        echo "to stderr" >&2
        """.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let log = folder.appending(path: "logs/jobs.log")
        let launcher = DetachedJobLauncher(executable: executable, log: log, environment: ["alfred_workflow_cache": "/tmp/x y", "PATH": "/usr/bin:/bin"])
        launcher.launch(.render(siteID: "s1"))

        var text = ""
        for _ in 0..<100 where !text.contains("to stderr") {
            try await Task.sleep(for: .milliseconds(50))
            text = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        }
        #expect(text.contains("args: render s1"))
        #expect(text.contains("setting: /tmp/x y"))
        #expect(text.contains("stdin: 0"))
        #expect(text.contains("own session"))
        #expect(text.contains("to stderr"))
    }

    @Test func aDetachedJobGetsThisBinaryAndTheJobsArguments() {
        let launcher = DetachedJobLauncher(executable: URL(filePath: "/w/netlify"), log: URL(filePath: "/c/jobs.log"), environment: ["B": "2", "A": "1"])
        #expect(launcher.commandLine(for: .render(siteID: "s1")) == ["/w/netlify", "render", "s1"])
        #expect(launcher.environmentStrings == ["A=1", "B=2"])
    }

    @Test func appleScriptTextIsPassedAsArgumentsNotSplicedIn() {
        let bundleID = "work.x\" & (do shell script \"id\") & \""
        let arguments = MacSystemActions.osascriptArguments(MacSystemActions.reopenScript, arguments: [bundleID])
        #expect(arguments.last == bundleID)
        #expect(!arguments.dropLast().contains { $0.contains(bundleID) })
        #expect(arguments.filter { $0 == "-e" }.count == MacSystemActions.reopenScript.count)
    }

    @Test func requestsKeepTheirMethodHeadersBodyAndTimeout() {
        let request = HTTPRequest(
            .post,
            URL(string: "https://api.netlify.com/api/v1/sites")!,
            headers: ["Authorization": "Bearer t", "User-Agent": "Mozilla/5.0"],
            body: Data("{}".utf8),
            timeout: 7
        )
        let urlRequest = URLSessionHTTPClient.urlRequest(for: request)
        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer t")
        #expect(urlRequest.value(forHTTPHeaderField: "User-Agent") == "Mozilla/5.0")
        #expect(urlRequest.httpBody == Data("{}".utf8))
        #expect(urlRequest.timeoutInterval == 7)
    }
}
