import Foundation

/// Persists recently opened files (paths in UserDefaults — app is non-sandboxed).
@MainActor
final class RecentStore: ObservableObject {
    @Published private(set) var urls: [URL] = []

    private let key = "recentFiles"
    private let limit = 30

    init() { load() }

    func add(_ url: URL) {
        urls.removeAll { $0 == url }
        urls.insert(url, at: 0)
        if urls.count > limit { urls = Array(urls.prefix(limit)) }
        save()
    }

    func remove(_ url: URL) {
        urls.removeAll { $0 == url }
        save()
    }

    func clear() {
        urls = []
        save()
    }

    private func load() {
        let paths = UserDefaults.standard.stringArray(forKey: key) ?? []
        let fm = FileManager.default
        urls = paths.map { URL(fileURLWithPath: $0) }.filter { fm.fileExists(atPath: $0.path) }
    }

    private func save() {
        UserDefaults.standard.set(urls.map(\.path), forKey: key)
    }
}
