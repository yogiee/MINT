import SwiftUI
import AppKit
import QuickLookThumbnailing

enum InspectorMode: String, CaseIterable, Identifiable {
    case pretty = "Pretty"
    case raw = "Raw"
    var id: String { rawValue }
}

/// The information pane: a summary card (thumbnail + name + specs) above the
/// field table, with the track selector as a floating capsule at the bottom.
struct ReportDetail: View {
    let report: MediaReport
    @Binding var selectedTrack: Track.ID?
    @Binding var mode: InspectorMode
    @Binding var showAllFields: Bool
    var search: String = ""

    private var isSearching: Bool { !search.trimmingCharacters(in: .whitespaces).isEmpty }

    private var activeTrack: Track? {
        report.track(id: selectedTrack)
            ?? report.track(id: report.defaultTrackID)
            ?? report.tracks.first
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationDocument(report.url)
            .safeAreaInset(edge: .bottom) {
                if mode == .pretty, !isSearching, report.railItems.count > 1 {
                    FloatingTrackPicker(items: report.railItems, selection: $selectedTrack)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
            }
            .onAppear { if selectedTrack == nil { selectedTrack = report.defaultTrackID } }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .pretty:
            if isSearching {
                SearchResults(report: report, query: search)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        SummaryCard(report: report)
                        if let track = activeTrack {
                            FieldRows(rows: showAllFields ? track.displayRows : track.curatedRows)
                        }
                    }
                    .padding(.bottom, 56) // clearance for the floating track picker
                }
            }
        case .raw:
            RawText(text: report.rawText)
        }
    }
}

/// Live filter across every field of every track.
struct SearchResults: View {
    let report: MediaReport
    let query: String

    private var groups: [(track: Track, rows: [DisplayRow])] {
        report.tracks.compactMap { track in
            let rows = track.displayRows.filter {
                $0.label.localizedCaseInsensitiveContains(query)
                    || $0.value.localizedCaseInsensitiveContains(query)
            }
            return rows.isEmpty ? nil : (track, rows)
        }
    }

    var body: some View {
        let groups = groups
        if groups.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(groups, id: \.track.id) { group in
                        Section {
                            FieldRows(rows: group.rows)
                        } header: {
                            Label(group.track.title, systemImage: group.track.kind.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(.bar)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
    }
}

// MARK: - Summary card

struct SummaryCard: View {
    let report: MediaReport
    @AppStorage(Prefs.fontSizeKey) private var fontSize = Prefs.fontSizeDefault

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ThumbnailView(url: report.url, fallbackSymbol: icon)
            VStack(alignment: .leading, spacing: 6) {
                Text(report.url.lastPathComponent)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(report.summaryChips.joined(separator: "  ·  "))
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary, lineWidth: 1))
        .padding(16)
    }

    private var icon: String {
        if report.firstVideo != nil { return "film" }
        if report.tracks.contains(where: { $0.kind == .image }) { return "photo" }
        if report.firstAudio != nil { return "waveform" }
        return "doc"
    }
}

/// QuickLook thumbnail for the file (cover art for audio), with an SF Symbol fallback.
struct ThumbnailView: View {
    let url: URL
    let fallbackSymbol: String
    @State private var image: NSImage?

    private let side: CGFloat = 76

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: 30))
                    .foregroundStyle(Color.mintAccent)
            }
        }
        .frame(width: side, height: side)
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary, lineWidth: 1))
        .task(id: url) { image = await Self.thumbnail(for: url, side: side) }
    }

    static func thumbnail(for url: URL, side: CGFloat) async -> NSImage? {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: side, height: side),
            scale: scale,
            representationTypes: .all
        )
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
                continuation.resume(returning: rep?.nsImage)
            }
        }
    }
}

// MARK: - Fields

struct FieldRows: View {
    let rows: [DisplayRow]
    @AppStorage(Prefs.fontSizeKey) private var fontSize = Prefs.fontSizeDefault
    @AppStorage(Prefs.rowSpacingKey) private var rowSpacing = Prefs.rowSpacingDefault

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(row.label)
                        .font(.system(size: fontSize))
                        .frame(width: fontSize * 14, alignment: .leading)
                        .foregroundStyle(.secondary)
                    CopyableValue(text: row.value)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, rowSpacing)
                .padding(.horizontal, 16)
                Divider().opacity(0.4)
            }
        }
    }
}

/// A value that copies to the clipboard on click, with a brief mint flash.
struct CopyableValue: View {
    let text: String
    @AppStorage(Prefs.fontSizeKey) private var fontSize = Prefs.fontSizeDefault
    @State private var copied = false

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, design: .monospaced))
            .textSelection(.enabled)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(copied ? Color.mintAccent.opacity(0.30) : .clear)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(text, forType: .string)
                withAnimation(.easeOut(duration: 0.12)) { copied = true }
                Task {
                    try? await Task.sleep(nanoseconds: 650_000_000)
                    withAnimation(.easeIn(duration: 0.25)) { copied = false }
                }
            }
            .help("Click to copy")
    }
}

// MARK: - Track picker / raw

struct FloatingTrackPicker: View {
    let items: [RailItem]
    @Binding var selection: Track.ID?

    var body: some View {
        Picker("Track", selection: $selection) {
            ForEach(items) { item in
                Label(item.title, systemImage: item.systemImage)
                    .tag(Optional(item.id))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .padding(5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
    }
}

struct RawText: View {
    let text: String
    @AppStorage(Prefs.fontSizeKey) private var fontSize = Prefs.fontSizeDefault

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(text.isEmpty ? "No raw output." : text)
                .font(.system(size: fontSize - 1, design: .monospaced))
                .textSelection(.enabled)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
