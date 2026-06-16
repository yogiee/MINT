import Foundation

/// A single inspector row after dedupe + humanization.
struct DisplayRow: Identifiable {
    let id = UUID()
    let key: String     // base mediainfo key
    let label: String   // human label
    let value: String   // preferred (humanized) value
}

extension Track {
    /// Strip mediainfo's display-variant suffixes: `BitRate_String3` → `BitRate`.
    static func baseKey(_ key: String) -> String {
        if let r = key.range(of: "_String[0-9]*$", options: .regularExpression) {
            return String(key[..<r.lowerBound])
        }
        return key
    }

    /// All fields collapsed to one row per base key, preferring mediainfo's
    /// pre-humanized `_String` value (e.g. "177 kb/s" over "176553").
    var displayRows: [DisplayRow] {
        var groups: [String: [Field]] = [:]
        var order: [String] = []
        for field in fields {
            let base = Track.baseKey(field.key)
            if groups[base] == nil { order.append(base) }
            groups[base, default: []].append(field)
        }
        return order.map { base in
            let group = groups[base] ?? []
            func value(_ k: String) -> String? { group.first { $0.key == k }?.value }
            let preferred = value(base + "_String")
                ?? value(base + "_String1")
                ?? value(base)
                ?? group.first?.value ?? ""
            return DisplayRow(key: base, label: Fmt.label(base), value: preferred)
        }
    }

    /// The curated, ordered subset for the default Pretty view.
    var curatedRows: [DisplayRow] {
        let priority = Track.priorityKeys(for: kind)
        let byKey = Dictionary(displayRows.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        let rows = priority.compactMap { byKey[$0] }
        return rows.isEmpty ? displayRows : rows
    }

    static func priorityKeys(for kind: TrackKind) -> [String] {
        switch kind {
        case .general:
            return ["Format", "Format_Profile", "CodecID", "FileSize", "Duration",
                    "OverallBitRate", "OverallBitRate_Mode", "FrameRate", "FrameCount",
                    "Title", "Movie", "Encoded_Date", "Recorded_Date",
                    "Encoded_Application", "Encoded_Library"]
        case .video:
            return ["Format", "Format_Profile", "Format_Level", "CodecID",
                    "Width", "Height", "DisplayAspectRatio", "PixelAspectRatio",
                    "FrameRate", "FrameRate_Mode", "BitRate", "BitRate_Mode",
                    "BitDepth", "ColorSpace", "ChromaSubsampling", "ScanType",
                    "Duration", "StreamSize", "Language", "Default", "Forced",
                    "Encoded_Library", "Title"]
        case .audio:
            return ["Format", "Format_Profile", "Format_AdditionalFeatures", "CodecID",
                    "Channels", "ChannelLayout", "ChannelPositions", "SamplingRate",
                    "BitRate", "BitRate_Mode", "BitDepth", "Compression_Mode",
                    "Duration", "StreamSize", "Language", "Default", "Forced", "Title"]
        case .image:
            return ["Format", "Format_Profile", "Width", "Height", "ColorSpace",
                    "ChromaSubsampling", "BitDepth", "StreamSize"]
        case .text:
            return ["Format", "CodecID", "Format_Profile", "Language",
                    "Default", "Forced", "Duration", "ElementCount", "Title"]
        case .menu, .other:
            return ["Format", "Duration"]
        }
    }
}

/// A row in the sidebar rail (image tiles collapse to one).
struct RailItem: Identifiable {
    let id: Track.ID
    let title: String
    let systemImage: String
    let badge: Int?
}

extension MediaReport {
    var railItems: [RailItem] {
        var items: [RailItem] = []
        var images: [Track] = []
        for track in tracks {
            if track.kind == .image { images.append(track); continue }
            items.append(RailItem(id: track.id, title: track.title,
                                  systemImage: track.kind.systemImage, badge: nil))
        }
        if let rep = images.first(where: { $0.firstValue("Format") != "Grid" }) ?? images.first {
            items.append(RailItem(id: rep.id,
                                  title: images.count > 1 ? "Images" : "Image",
                                  systemImage: TrackKind.image.systemImage,
                                  badge: images.count > 1 ? images.count : nil))
        }
        return items
    }

    func track(id: Track.ID?) -> Track? {
        guard let id else { return nil }
        return tracks.first { $0.id == id }
    }

    /// Sensible default selection: first non-general track, else the first track.
    var defaultTrackID: Track.ID? {
        railItems.first(where: { track(id: $0.id)?.kind != .general })?.id
            ?? railItems.first?.id
    }
}
