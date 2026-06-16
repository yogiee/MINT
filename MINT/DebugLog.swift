import Foundation

/// Phase-0 only: appends a timestamped line to ~/MINT-phase0-log.txt and the
/// system log, so we can verify Open-With delivery without staring at the GUI.
/// Removed once Phase 0 is proven.
enum DebugLog {
    static let fileURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("MINT-phase0-log.txt")

    static func write(_ message: String) {
#if DEBUG
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(stamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: fileURL)
            }
        }
        NSLog("MINT: %@", message)
#endif
    }
}
