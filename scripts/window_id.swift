// window_id WIDTH: print the window number of the on-screen Alfred window that is WIDTH points wide.
import CoreGraphics
guard let width = Double(CommandLine.arguments.dropFirst().first ?? "") else { exit(2) }
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows where (window["kCGWindowOwnerName"] as? String ?? "").hasPrefix("Alfred") {
    if let bounds = window["kCGWindowBounds"] as? [String: Double], bounds["Width"] == width {
        print(window["kCGWindowNumber"]!)
        break
    }
}
