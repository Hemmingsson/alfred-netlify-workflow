import NetlifyCore
import NetlifyTesting
import Testing

@Suite("Job locks")
struct JobLockTests {
    let test = TestContext()

    @Test func heldOnlyWhileTheJobRuns() async {
        let lock = JobLock(.refresh, paths: test.paths)
        #expect(!lock.isHeld)
        let ran = await lock.tryHolding {
            #expect(lock.isHeld)
            let again = await lock.tryHolding { true }
            #expect(again == nil)
            return true
        }
        #expect(ran == true)
        #expect(!lock.isHeld)
    }

    @Test func eachSiteRendersUnderItsOwnLock() async {
        let first = JobLock(.render(siteID: "a1"), paths: test.paths)
        let other = JobLock(.render(siteID: "b2"), paths: test.paths)
        await first.tryHolding {
            #expect(!other.isHeld)
        }
    }

    @Test func lockNamesAreSafeFileNames() {
        let lock = JobLock(.render(siteID: "../../x y"), paths: test.paths)
        #expect(lock.file.lastPathComponent == "render-xy.lock")
        #expect(lock.file.deletingLastPathComponent() == test.paths.locksFolder)
    }
}
