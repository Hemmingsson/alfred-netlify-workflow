import Foundation

/// Why a picture couldn't be fetched, rendered or stored. Worded for `jobs.log` and the deploy's failure records.
enum PictureError: Error, Equatable, LocalizedError {
    /// The server answered, but not with success.
    case httpStatus(Int)
    /// The bytes aren't an image ImageIO can read.
    case notAnImage
    /// The image couldn't be encoded or written.
    case cannotWrite
    /// The site has nothing published at an address, so it has no pictures.
    case unpublished
    /// The page to render didn't load: DNS, TLS, connection refused, …
    case pageDidNotLoad(String)
    /// Nothing of the page to render arrived before the time limit.
    case timedOut
    /// WebKit gave no snapshot of the rendered page.
    case noSnapshot

    var errorDescription: String? {
        switch self {
        case .httpStatus(let status): "HTTP \(status)"
        case .notAnImage: "not an image"
        case .cannotWrite: "couldn't write the image"
        case .unpublished: "the site has nothing published"
        case .pageDidNotLoad(let reason): "page didn't load: \(reason)"
        case .timedOut: "nothing arrived in time"
        case .noSnapshot: "WebKit gave no snapshot"
        }
    }
}
