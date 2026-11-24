// swift-tools-version: 6.0
// The `netlify` binary the Alfred workflow runs, and the `demo` tool. See docs/architecture.md.
import PackageDescription

let package = Package(
    name: "alfred-netlify",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "netlify", targets: ["netlify"]),
        .executable(name: "demo", targets: ["demo"]),
    ],
    targets: [
        // Shared: models, the cache folder, the Context protocols, the Alfred UI reply types.
        .target(name: "NetlifyCore"),
        // The Netlify account, the pictures and the window. Each depends on NetlifyCore only; NetlifyCLI plugs them
        // together.
        .target(name: "NetlifyAPI", dependencies: ["NetlifyCore"]),
        .target(name: "NetlifyPictures", dependencies: ["NetlifyCore"]),
        .target(name: "NetlifyWindow", dependencies: ["NetlifyCore"]),
        .target(name: "NetlifyCLI", dependencies: ["NetlifyCore", "NetlifyAPI", "NetlifyPictures", "NetlifyWindow"]),
        .executableTarget(name: "netlify", dependencies: ["NetlifyCLI"]),
        .executableTarget(name: "demo", dependencies: ["NetlifyCore", "NetlifyPictures"]),

        // Fakes and fixtures for tests; never linked into the binaries.
        .target(name: "NetlifyTesting", dependencies: ["NetlifyCore"], path: "Tests/NetlifyTesting"),
        .testTarget(name: "NetlifyCoreTests", dependencies: ["NetlifyCore", "NetlifyTesting"]),
        .testTarget(name: "NetlifyAPITests", dependencies: ["NetlifyAPI", "NetlifyTesting"]),
        .testTarget(name: "NetlifyPicturesTests", dependencies: ["NetlifyPictures", "NetlifyTesting"]),
        .testTarget(name: "NetlifyWindowTests", dependencies: ["NetlifyWindow", "NetlifyTesting"]),
        .testTarget(name: "NetlifyCLITests", dependencies: ["NetlifyCLI", "demo", "NetlifyTesting"]),
    ],
    swiftLanguageModes: [.v6]
)
