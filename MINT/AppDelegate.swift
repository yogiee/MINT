import AppKit

/// Routes every Finder "Open With" / drop-on-Dock file to a window, giving each
/// file its own independent window.
///
/// Ordering-proof: a file either fills an empty window that's *waiting* for one,
/// or spawns a new window that pulls it on appear, or is buffered until the first
/// window exists. This avoids the cold-launch race (window appears before the
/// open event, or vice-versa) without ever leaving a stray empty window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var pending: [URL] = []
    private var waitingLoader: ((URL) -> Void)?
    private var openWindowAction: (() -> Void)?
    private var didBootstrap = false

    // MARK: Open paths

    func application(_ application: NSApplication, open urls: [URL]) {
        enqueue(urls)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        enqueue([URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        enqueue(filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: .success)
    }

    func enqueue(_ urls: [URL]) {
        urls.forEach(route)
    }

    private func route(_ url: URL) {
        if let load = waitingLoader {
            waitingLoader = nil
            DebugLog.write("fill waiting window: \(url.lastPathComponent)")
            load(url)
        } else if let open = openWindowAction {
            DebugLog.write("open new window: \(url.lastPathComponent)")
            pending.append(url)
            open()
        } else {
            DebugLog.write("buffer (cold): \(url.lastPathComponent)")
            pending.append(url)
        }
    }

    /// Called once per window on first appearance.
    /// Returns a file to show immediately, or registers the window as the one
    /// the next incoming file should fill (so it won't be left empty).
    func windowReady(loadInPlace: @escaping (URL) -> Void,
                     opener: @escaping () -> Void) -> URL? {
        openWindowAction = opener
        var mine: URL?
        if !pending.isEmpty {
            mine = pending.removeFirst()
        } else {
            waitingLoader = loadInPlace
        }
        if !didBootstrap {
            didBootstrap = true
            for _ in 0..<pending.count { opener() }   // backlog → one window each
        }
        return mine
    }

    /// An empty window going away should stop being the fill target.
    func windowClosing(isWaiting: Bool) {
        if isWaiting { waitingLoader = nil }
    }
}
