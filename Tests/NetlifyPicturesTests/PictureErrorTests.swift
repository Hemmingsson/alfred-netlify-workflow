import Foundation
@testable import NetlifyPictures
import Testing

@Suite("Picture errors in the job log")
struct PictureErrorTests {
    @Test func ourErrorsReadAsTheirDescription() {
        #expect(PictureError.httpStatus(404).localizedDescription == "HTTP 404")
        #expect(PictureError.timedOut.localizedDescription == "nothing arrived in time")
    }

    @Test func systemErrorsAreOneLineWithoutTheirUserInfo() {
        let error: any Error = URLError(.cannotFindHost, userInfo: [
            NSLocalizedDescriptionKey: "A server with the specified hostname could not be found.",
            "_NSURLErrorRelatedURLSessionTaskErrorKey": "(\n    \"LocalDataTask <1>\"\n)",
        ])
        #expect(error.localizedDescription == "A server with the specified hostname could not be found.")
    }
}
