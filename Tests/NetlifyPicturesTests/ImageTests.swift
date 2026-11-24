import CoreGraphics
import Foundation
@testable import NetlifyPictures
import Testing

@Suite("Images")
struct ImageTests {
    @Test func thumbnailsCoverAndAreCutFromTheTop() throws {
        // A tall page: only its top 300 of 3000 rows are red.
        let page = try #require(CGImage.decoded(from: TestImages.png(width: 1000, height: 3000, topRows: 300)))
        let thumbnail = try #require(page.croppedToCover(width: 320, height: 200))
        #expect(thumbnail.width == 320 && thumbnail.height == 200)
        #expect(TestImages.colour(of: thumbnail, x: 160, y: 5) == (255, 0, 0))
        #expect(TestImages.colour(of: thumbnail, x: 160, y: 195) == (0, 0, 255))
    }

    @Test func screenshotsScaleToThumbnailSize() throws {
        let screenshot = try #require(CGImage.decoded(from: TestImages.png(width: 960, height: 600, topRows: 300)))
        let thumbnail = try #require(screenshot.croppedToCover(width: 320, height: 200))
        #expect(TestImages.colour(of: thumbnail, x: 10, y: 90) == (255, 0, 0))
        #expect(TestImages.colour(of: thumbnail, x: 10, y: 110) == (0, 0, 255))
    }

    @Test func faviconsShrinkToFitButNeverGrow() throws {
        let big = try #require(CGImage.decoded(from: TestImages.png(width: 180, height: 90)))
        let fitted = try #require(big.scaledToFit(longestSide: 64))
        #expect(fitted.width == 64 && fitted.height == 32)
        let small = try #require(CGImage.decoded(from: TestImages.png(width: 16, height: 16)))
        #expect(small.scaledToFit(longestSide: 64)?.width == 16)
    }

    @Test func htmlIsNotTakenForSVG() {
        #expect(DeployPictures.isSVG(Data(#"<?xml version="1.0"?><svg xmlns="http://www.w3.org/2000/svg"/>"#.utf8)))
        #expect(!DeployPictures.isSVG(Data("<!DOCTYPE html><html><body><svg></svg></body></html>".utf8)))
    }
}
