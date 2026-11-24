// Display a real backdrop below Alfred so macOS renders its live material blur.
// Writes the screen capture rectangle to READY and stays alive until terminated.
import AppKit
import CoreGraphics

guard CommandLine.arguments.count == 4,
      let id = UInt32(CommandLine.arguments[1]),
      let wallpaper = NSImage(contentsOfFile: CommandLine.arguments[2]),
      let windows = CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]],
      let info = windows.first,
      let dictionary = info[kCGWindowBounds as String] as? [String: Any],
      let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary) else { exit(1) }
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let desktopHeight = NSScreen.screens[0].frame.height
let cocoaBounds = NSRect(x: bounds.minX, y: desktopHeight - bounds.maxY, width: bounds.width, height: bounds.height)
let screen = NSScreen.screens.first { $0.frame.intersects(cocoaBounds) } ?? NSScreen.screens[0]
let backdrop = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
backdrop.level = NSWindow.Level(rawValue: (info[kCGWindowLayer as String] as? Int ?? 0) - 1)
backdrop.ignoresMouseEvents = true
backdrop.hasShadow = false
final class WallpaperView: NSView {
    var wallpaper: NSImage!
    override func draw(_ dirtyRect: NSRect) {
        let scale = max(bounds.width / wallpaper.size.width, bounds.height / wallpaper.size.height)
        let size = NSSize(width: wallpaper.size.width * scale, height: wallpaper.size.height * scale)
        wallpaper.draw(in: NSRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height))
    }
}
let view = WallpaperView(frame: NSRect(origin: .zero, size: screen.frame.size))
view.wallpaper = wallpaper
backdrop.contentView = view
backdrop.orderFrontRegardless()
view.display()
let screenBounds = CGRect(x: screen.frame.minX, y: desktopHeight - screen.frame.maxY, width: screen.frame.width, height: screen.frame.height)
let capture = bounds.insetBy(dx: -60, dy: -60).intersection(screenBounds)
try "\(Int(capture.minX)),\(Int(capture.minY)),\(Int(capture.width)),\(Int(capture.height))".write(toFile: CommandLine.arguments[3], atomically: true, encoding: .utf8)
app.run()
