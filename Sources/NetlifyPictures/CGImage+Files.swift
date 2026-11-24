import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

extension CGImage {
    /// The image in `data` (PNG, JPEG, GIF, ICO, WebP, … anything ImageIO reads). For files holding several images,
    /// such as an ICO with many sizes, the largest one.
    static func decoded(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let images = (0..<CGImageSourceGetCount(source)).compactMap { CGImageSourceCreateImageAtIndex(source, $0, nil) }
        return images.max { $0.width * $0.height < $1.width * $1.height }
    }

    /// The image in a file, or nil when it can't be read.
    static func decoded(contentsOf file: URL) -> CGImage? {
        (try? Data(contentsOf: file)).flatMap(decoded(from:))
    }

    /// The image as PNG bytes.
    func pngData() throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw PictureError.cannotWrite
        }
        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else { throw PictureError.cannotWrite }
        return data as Data
    }

    /// Write the image as a PNG, atomically (a reader never sees half a file), creating the folder when missing.
    func writePNG(to file: URL) throws {
        let data = try pngData()
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
    }
}
