import Foundation

/// The parsed result of running `mediainfo` on one file.
struct MediaReport: Sendable {
    let url: URL
    let tracks: [Track]
    /// Verbatim `mediainfo --Full` text output, for the Raw view.
    let rawText: String

    var general: Track? { tracks.first { $0.kind == .general } }
    var firstVideo: Track? { tracks.first { $0.kind == .video } }
    var firstAudio: Track? { tracks.first { $0.kind == .audio } }

    /// Tracks minus the duplicated tile-images some containers (HEIC) emit —
    /// keeps the rail readable while the full set stays available in Raw.
    var displayTracks: [Track] { tracks }
}

enum TrackKind: String, Sendable, CaseIterable {
    case general = "General"
    case video   = "Video"
    case audio   = "Audio"
    case text    = "Text"
    case image   = "Image"
    case menu    = "Menu"
    case other   = "Other"

    var label: String { rawValue }

    var systemImage: String {
        switch self {
        case .general: return "doc"
        case .video:   return "film"
        case .audio:   return "waveform"
        case .text:    return "captions.bubble"
        case .image:   return "photo"
        case .menu:    return "list.bullet"
        case .other:   return "questionmark.square.dashed"
        }
    }
}

struct Track: Identifiable, Sendable {
    let id = UUID()
    let kind: TrackKind
    /// `@typeorder` from mediainfo, e.g. Audio #1, #2 (nil when single).
    let typeOrder: Int?
    /// All key/value pairs for this track, including flattened `extra`.
    let fields: [Field]

    private let lookup: [String: String]

    init(kind: TrackKind, typeOrder: Int?, fields: [Field]) {
        self.kind = kind
        self.typeOrder = typeOrder
        self.fields = fields
        self.lookup = Dictionary(fields.map { ($0.key, $0.value) },
                                 uniquingKeysWith: { first, _ in first })
    }

    func value(_ key: String) -> String? { lookup[key] }

    /// First non-empty value among the given keys (mediainfo names drift by format).
    func firstValue(_ keys: String...) -> String? {
        for key in keys {
            if let v = lookup[key], !v.isEmpty { return v }
        }
        return nil
    }

    /// Display name for the rail, e.g. "Audio 2".
    var title: String {
        if let typeOrder, typeOrder > 0 { return "\(kind.label) \(typeOrder)" }
        return kind.label
    }
}

struct Field: Identifiable, Sendable {
    let id = UUID()
    let key: String
    let value: String
}
