import SwiftUI

/// Per-window state: owns the single `Document` for this window's file.
@MainActor
final class WindowModel: ObservableObject {
    @Published private(set) var document: Document?
    private var loadedURL: URL?

    /// Load the file the window is bound to (no-op if unchanged).
    func sync(to url: URL?, recents: RecentStore) {
        guard url != loadedURL else { return }
        loadedURL = url
        guard let url else { document = nil; return }
        recents.add(url)
        let doc = Document(url: url)
        document = doc
        doc.load()
    }
}
