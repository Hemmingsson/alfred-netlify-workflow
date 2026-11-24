import Foundation
import NetlifyCore

/// SystemActions that only record what they were asked to do.
public final class FakeSystemActions: SystemActions {
    public enum Call: Equatable, Sendable {
        case opened(URL)
        case copied(String)
        case reopenedWindow
    }

    private let log = Locked<[Call]>([])

    public init() {}

    public var calls: [Call] { log.value }

    public func open(_ url: URL) { log.withLock { $0.append(.opened(url)) } }

    public func copy(_ text: String) { log.withLock { $0.append(.copied(text)) } }

    public func reopenWindow() { log.withLock { $0.append(.reopenedWindow) } }
}
