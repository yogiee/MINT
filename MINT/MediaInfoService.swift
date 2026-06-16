import Foundation

/// Runs the `mediainfo` CLI off the main thread and parses its output.
///
/// Locates the binary bundled-first (self-contained shipping build), then falls
/// back to a Homebrew/local install during development.
actor MediaInfoService {
    static let shared = MediaInfoService()

    enum ServiceError: LocalizedError {
        case binaryNotFound
        case launchFailed(String)
        case emptyOutput
        case parseFailed(String)

        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                return "Couldn't find the mediainfo tool. Install it with: brew install mediainfo"
            case .launchFailed(let why):
                return "Couldn't run mediainfo: \(why)"
            case .emptyOutput:
                return "mediainfo returned nothing — the file may be unreadable or not a media file."
            case .parseFailed(let why):
                return "Couldn't read mediainfo's output: \(why)"
            }
        }
    }

    private let binaryURL: URL?

    init() { self.binaryURL = Self.locateBinary() }

    var isAvailable: Bool { binaryURL != nil }

    func analyze(_ url: URL) async throws -> MediaReport {
        guard let exe = binaryURL else { throw ServiceError.binaryNotFound }
        let path = url.path

        // JSON (structured) and text (Raw view) in parallel, off the cooperative pool.
        async let jsonData = Self.run(exe, ["--Output=JSON", "--Full", path])
        async let textData = Self.run(exe, ["--Full", path])

        let json = try await jsonData
        let text = String(data: try await textData, encoding: .utf8) ?? ""

        guard !json.isEmpty else { throw ServiceError.emptyOutput }
        let tracks = try Self.parseTracks(from: json)
        return MediaReport(url: url, tracks: tracks, rawText: text)
    }

    // MARK: Binary location

    private static func locateBinary() -> URL? {
        let fm = FileManager.default

        // 1. Bundled inside the app (shipping, self-contained).
        if let bundled = Bundle.main.url(forResource: "mediainfo", withExtension: nil, subdirectory: "MediaInfoCLI"),
           fm.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        if let bundled = Bundle.main.url(forResource: "mediainfo", withExtension: nil),
           fm.isExecutableFile(atPath: bundled.path) {
            return bundled
        }

        // 2. Common install locations (development / fallback).
        for path in ["/opt/homebrew/bin/mediainfo", "/usr/local/bin/mediainfo", "/usr/bin/mediainfo"] {
            if fm.isExecutableFile(atPath: path) { return URL(fileURLWithPath: path) }
        }
        return nil
    }

    // MARK: Process

    private static func run(_ exe: URL, _ args: [String]) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = exe
            process.arguments = args
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            do {
                try process.run()
            } catch {
                throw ServiceError.launchFailed(error.localizedDescription)
            }
            // Read fully before waiting to avoid pipe-buffer deadlock on large output.
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return data
        }.value
    }

    // MARK: Parsing

    private static func parseTracks(from data: Data) throws -> [Track] {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ServiceError.parseFailed(error.localizedDescription)
        }
        guard let obj = root as? [String: Any],
              let media = obj["media"] as? [String: Any] else {
            throw ServiceError.parseFailed("unexpected JSON shape")
        }

        let rawTracks: [[String: Any]]
        if let array = media["track"] as? [[String: Any]] {
            rawTracks = array
        } else if let single = media["track"] as? [String: Any] {
            rawTracks = [single]
        } else {
            throw ServiceError.parseFailed("no tracks")
        }

        return rawTracks.map(Self.makeTrack(from:))
    }

    private static func makeTrack(from dict: [String: Any]) -> Track {
        let typeString = (dict["@type"] as? String) ?? "Other"
        let kind = TrackKind(rawValue: typeString) ?? .other
        let typeOrder = (dict["@typeorder"] as? String).flatMap(Int.init)

        var fields: [Field] = []
        for (key, value) in dict {
            if key.hasPrefix("@") { continue }
            if let string = value as? String {
                fields.append(Field(key: key, value: string))
            } else if let extra = value as? [String: Any] {
                // mediainfo nests format-specific odds and ends under "extra".
                for (subKey, subValue) in extra {
                    if let string = subValue as? String {
                        fields.append(Field(key: subKey, value: string))
                    }
                }
            }
        }
        return Track(kind: kind, typeOrder: typeOrder, fields: fields)
    }
}
