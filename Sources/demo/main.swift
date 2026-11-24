// The demo tool for README screenshots (scripts/screenshot.sh runs it):
//
//     swift run demo build <folder>    write a demo account folder: made-up sites, pictures and favicons from demo/
//
// The workflow reads that folder instead of the Netlify account when `netlify_demo` points at it.
import Foundation
import NetlifyPictures

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 2, arguments[0] == "build" else {
    FileHandle.standardError.write(Data("usage: demo build <folder>\n".utf8))
    exit(2)
}

// This file is Sources/demo/main.swift, so the repository is two folders up.
let repository = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let folder = URL(filePath: arguments[1], directoryHint: .isDirectory).standardizedFileURL
let builder = DemoAccountBuilder(
    sources: repository.appending(path: "demo", directoryHint: .isDirectory),
    workflowFolder: repository.appending(path: "workflow", directoryHint: .isDirectory),
    now: Date(),
    makePictures: { PictureStore(context: $0) }
)
do {
    let sites = try builder.build(into: folder)
    print("\(sites.count) demo sites in \(folder.path)")
} catch {
    FileHandle.standardError.write(Data("demo: \(error.localizedDescription)\n".utf8))
    exit(1)
}
