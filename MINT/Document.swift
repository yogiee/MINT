import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// One opened file: owns its load state and parsed report.
@MainActor
final class Document: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL

    enum State {
        case loading
        case ready(MediaReport)
        case failed(String)
    }

    @Published private(set) var state: State = .loading

    init(url: URL) { self.url = url }

    var name: String { url.lastPathComponent }

    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    /// The whole report as text — raw mediainfo output, or all curated fields.
    func reportText(raw: Bool) -> String? {
        guard case .ready(let report) = state else { return nil }
        if raw { return report.rawText }
        return report.tracks.map { track in
            let body = track.displayRows
                .map { "  \($0.label): \($0.value)" }
                .joined(separator: "\n")
            return "[\(track.title)]\n\(body)"
        }.joined(separator: "\n\n")
    }

    func copyReport(raw: Bool) {
        guard let text = reportText(raw: raw) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    /// Save the report to a .txt file via a save panel.
    func export(raw: Bool) {
        guard let text = reportText(raw: raw) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + " — mediainfo.txt"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let out = panel.url {
            try? text.write(to: out, atomically: true, encoding: .utf8)
        }
    }

    func load() {
        state = .loading
        Task {
            do {
                let report = try await MediaInfoService.shared.analyze(url)
                state = .ready(report)
            } catch {
                state = .failed((error as? LocalizedError)?.errorDescription
                                ?? error.localizedDescription)
            }
        }
    }
}
