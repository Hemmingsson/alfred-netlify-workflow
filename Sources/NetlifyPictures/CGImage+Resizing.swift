import CoreGraphics

extension CGImage {
    /// Scaled to cover `width`×`height` and cut from the top, centred horizontally: the top of a page as a thumbnail.
    func croppedToCover(width: Int, height: Int) -> CGImage? {
        let scale = max(Double(width) / Double(self.width), Double(height) / Double(self.height))
        let scaledWidth = Double(self.width) * scale
        let scaledHeight = Double(self.height) * scale
        // Core Graphics puts the origin at the bottom left, so the top of the image sits at `height`.
        let rect = CGRect(x: (Double(width) - scaledWidth) / 2, y: Double(height) - scaledHeight, width: scaledWidth, height: scaledHeight)
        return drawn(width: width, height: height, in: rect)
    }

    /// Scaled down, keeping its shape, so its longer side is at most `longestSide`. Smaller images stay as they are.
    func scaledToFit(longestSide: Int) -> CGImage? {
        let scale = min(1, Double(longestSide) / Double(max(width, height)))
        let newWidth = max(1, Int((Double(width) * scale).rounded()))
        let newHeight = max(1, Int((Double(height) * scale).rounded()))
        return drawn(width: newWidth, height: newHeight, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
    }

    /// This image drawn into `rect` of a new transparent sRGB bitmap of `width`×`height` pixels.
    private func drawn(width: Int, height: Int, in rect: CGRect) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        context.interpolationQuality = .high
        context.draw(self, in: rect)
        return context.makeImage()
    }
}
