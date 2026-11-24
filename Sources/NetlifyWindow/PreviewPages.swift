import Foundation
import NetlifyCore

/// The live preview pages, one per site in `account/previews/`. A page shows the site's picture at once and loads
/// the real site in an iframe laid out at desktop width, scaled to the pane, fading in once it has loaded. Alfred UI
/// has no "page loaded" event, so the crossfade happens inside the page. It lives in the cache folder so `file://`
/// reaches the picture.
struct PreviewPages: Sendable {
    let paths: Paths

    /// The page for a site, written when it changed; nil when the folder can't be written.
    func page(siteID: String, url: URL, picture: URL?) -> URL? {
        let file = paths.previewsFolder.appending(path: Paths.fileSafe(siteID) + ".html")
        let html = Self.html(url: url, picture: picture)
        if (try? String(contentsOf: file, encoding: .utf8)) != html {
            do {
                try FileManager.default.createDirectory(at: paths.previewsFolder, withIntermediateDirectories: true)
                try Data(html.utf8).write(to: file, options: .atomic)
            } catch {
                return nil
            }
        }
        return file
    }

    /// Delete pages of sites that are gone.
    func tidy(keeping siteIDs: [String]) {
        let keep = Set(siteIDs.map { Paths.fileSafe($0) + ".html" })
        let files = (try? FileManager.default.contentsOfDirectory(at: paths.previewsFolder, includingPropertiesForKeys: nil)) ?? []
        for file in files where !keep.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// The width the site is laid out at before scaling.
    static let desktopWidth = 1440

    static func html(url: URL, picture: URL?) -> String {
        let image = picture.map { #"<img src="\#(escape($0.absoluteString))" alt="">"# } ?? ""
        return """
        <!doctype html><html><head><meta charset=utf-8><style>
        html,body{margin:0;height:100%;overflow:hidden;background:#111}
        img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:top}
        iframe{border:0;position:absolute;left:0;top:0;width:\(desktopWidth)px;transform-origin:0 0;background:#fff;opacity:0;transition:opacity .25s}
        iframe.on{opacity:1}
        </style></head><body>\(image)<iframe id=f src="\(escape(url.absoluteString))"></iframe><script>
        var f=document.getElementById('f');
        function fit(){var k=innerWidth/\(desktopWidth);f.style.transform='scale('+k+')';f.style.height=(innerHeight/k)+'px'}
        fit();addEventListener('resize',fit);
        f.addEventListener('load',function(){setTimeout(function(){f.className='on'},200)});
        </script></body></html>

        """
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
