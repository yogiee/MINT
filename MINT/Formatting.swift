import Foundation

/// Small value/label formatters shared by the summary and inspector.
enum Fmt {
    static func bytes(_ raw: String?) -> String? {
        guard let raw, let n = Int64(raw) else { return nil }
        return ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }

    static func duration(_ raw: String?) -> String? {
        guard let raw, let seconds = Double(raw) else { return nil }
        let total = Int(seconds.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }

    static func fps(_ raw: String?) -> String? {
        guard let raw, let f = Double(raw) else { return raw.map { "\($0) fps" } }
        if f == f.rounded() { return "\(Int(f)) fps" }
        return String(format: "%.3f fps", f)
    }

    /// Prettify a mediainfo key into a human label: "OverallBitRate_Mode" → "Overall Bit Rate Mode".
    static func label(_ key: String) -> String {
        let spaced = key.replacingOccurrences(of: "_", with: " ")
        var result = ""
        let chars = Array(spaced)
        for (i, c) in chars.enumerated() {
            if i > 0, c.isUppercase {
                let prev = chars[i - 1]
                let next = i + 1 < chars.count ? chars[i + 1] : " "
                // Insert a space at lower→Upper, or at the end of an ACRONYM run.
                if prev.isLowercase || prev.isNumber || (prev.isUppercase && next.isLowercase) {
                    result.append(" ")
                }
            }
            result.append(c)
        }
        return result
    }
}

extension MediaReport {
    /// The at-a-glance chips for the summary header.
    var summaryChips: [String] {
        var chips: [String] = []
        if let container = general?.firstValue("Format") { chips.append(container) }

        var codecs: [String] = []
        if let v = firstVideo?.firstValue("Format") { codecs.append(v) }
        if let a = firstAudio?.firstValue("Format") { codecs.append(a) }
        if codecs.isEmpty, let img = tracks.first(where: { $0.kind == .image })?.firstValue("Format") {
            codecs.append(img)
        }
        if !codecs.isEmpty { chips.append(codecs.joined(separator: " + ")) }

        let visual = firstVideo ?? tracks.first { $0.kind == .image }
        if let w = visual?.firstValue("Width"), let h = visual?.firstValue("Height") {
            chips.append("\(w)×\(h)")
        }
        if let fps = Fmt.fps(firstVideo?.firstValue("FrameRate") ?? general?.firstValue("FrameRate")) {
            chips.append(fps)
        }
        if let dur = Fmt.duration(general?.firstValue("Duration")) { chips.append(dur) }
        if let size = Fmt.bytes(general?.firstValue("FileSize")) { chips.append(size) }
        return chips
    }
}
