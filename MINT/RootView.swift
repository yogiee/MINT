import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Root of a single window. Owns its own state; pulls its file on appear.
struct WindowRoot: View {
    @EnvironmentObject private var recents: RecentStore
    @EnvironmentObject private var appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow
    @AppStorage("appearance") private var appearance: Appearance = .system

    @StateObject private var model = WindowModel()
    @State private var hasAppeared = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var selectedTrack: Track.ID?
    @State private var mode: InspectorMode = .pretty
    @State private var showAllFields = false
    @State private var search = ""
    @State private var searchVisible = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            RecentSidebar(recents: recents, activeURL: model.document?.url) { open($0) }
                .navigationSplitViewColumnWidth(min: 210, ideal: 250, max: 340)
        } detail: {
            DetailColumn(document: model.document,
                         selectedTrack: $selectedTrack,
                         mode: $mode,
                         showAllFields: $showAllFields,
                         search: $search,
                         searchVisible: $searchVisible)
        }
        .tint(.mintAccent)
        .onChange(of: searchVisible) { if !searchVisible { search = "" } }
        .toolbar { appearanceToolbar }
        .onAppear {
            appearance.apply()
            guard !hasAppeared else { return }
            hasAppeared = true
            if let mine = appDelegate.windowReady(
                loadInPlace: { model.sync(to: $0, recents: recents) },
                opener: { openWindow(id: "main") }
            ) {
                model.sync(to: mine, recents: recents)
            }
        }
        .onChange(of: appearance) { appearance.apply() }
        .onChange(of: model.document?.id) { selectedTrack = nil; search = "" }
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
    }

    @ToolbarContentBuilder
    private var appearanceToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { option in
                        Label(option.label, systemImage: option.symbol).tag(option)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Appearance", systemImage: appearance.symbol)
            }
            .help("Light, Dark, or System appearance")
        }
    }

    /// Open a file: into this window if empty, otherwise a new window.
    private func open(_ url: URL) {
        if model.document == nil {
            load(url, inPlace: true)
        } else {
            appDelegate.enqueue([url])
        }
    }

    private func load(_ url: URL, inPlace: Bool) {
        model.sync(to: url, recents: recents)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { dropped, _ in
            guard let dropped else { return }
            Task { @MainActor in open(dropped) }
        }
        return true
    }
}

// MARK: - Recents sidebar

struct RecentSidebar: View {
    @ObservedObject var recents: RecentStore
    var activeURL: URL?
    var onOpen: (URL) -> Void

    var body: some View {
        List {
            if recents.urls.isEmpty {
                Text("No recent files")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            } else {
                Section("Recent") {
                    ForEach(recents.urls, id: \.self) { url in
                        let isActive = url == activeURL
                        Button { onOpen(url) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: Self.icon(for: url))
                                    .foregroundStyle(Color.mintAccent)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(url.lastPathComponent)
                                        .fontWeight(isActive ? .semibold : .regular)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text(url.deletingLastPathComponent().path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.head)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isActive ? Color.mintAccent.opacity(0.18) : .clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                        .contextMenu {
                            Button("Open in New Window") { onOpen(url) }
                            Button("Remove from Recents") { recents.remove(url) }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !recents.urls.isEmpty {
                Button("Clear Recents") { recents.clear() }
                    .buttonStyle(.borderless)
                    .padding(8)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    static func icon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mp4", "mov", "mkv", "avi", "m4v", "webm", "ts", "mpg", "mpeg", "wmv", "flv":
            return "film"
        case "mp3", "aac", "flac", "wav", "aiff", "aif", "m4a", "ogg", "opus", "alac":
            return "waveform"
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "webp", "bmp", "raw", "dng":
            return "photo"
        default:
            return "doc"
        }
    }
}

// MARK: - Detail

struct DetailColumn: View {
    var document: Document?
    @Binding var selectedTrack: Track.ID?
    @Binding var mode: InspectorMode
    @Binding var showAllFields: Bool
    @Binding var search: String
    @Binding var searchVisible: Bool

    var body: some View {
        Group {
            if let document {
                DocumentDetail(document: document,
                               selectedTrack: $selectedTrack,
                               mode: $mode,
                               showAllFields: $showAllFields,
                               search: $search,
                               searchVisible: $searchVisible)
            } else {
                EmptyStateView()
            }
        }
        .navigationTitle(document?.name ?? "MINT")
    }
}

struct DocumentDetail: View {
    @ObservedObject var document: Document
    @Binding var selectedTrack: Track.ID?
    @Binding var mode: InspectorMode
    @Binding var showAllFields: Bool
    @Binding var search: String
    @Binding var searchVisible: Bool

    // Only Pretty mode is filterable; closing search clears the filter.
    private var effectiveSearch: String {
        (searchVisible && mode == .pretty) ? search : ""
    }

    var body: some View {
        switch document.state {
        case .loading:
            VStack(spacing: 10) {
                ProgressView()
                Text("Reading \(document.name)…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't read this file", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            }
        case .ready(let report):
            ReportDetail(report: report,
                         selectedTrack: $selectedTrack,
                         mode: $mode,
                         showAllFields: $showAllFields,
                         search: effectiveSearch)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if searchVisible, mode == .pretty {
                        SearchBar(text: $search) { searchVisible = false }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        if mode == .pretty {
                            Toggle(isOn: $searchVisible) {
                                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                            }
                            .help("Filter fields (⌘F)")
                            .keyboardShortcut("f", modifiers: .command)

                            Toggle(isOn: $showAllFields) {
                                Label("All fields", systemImage: "list.bullet.indent")
                            }
                            .help("Show every field, not just the key ones")
                        }

                        Picker("View", selection: $mode) {
                            ForEach(InspectorMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .help("Pretty or raw mediainfo output")

                        Button { document.copyReport(raw: mode == .raw) } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .help(mode == .raw ? "Copy raw output" : "Copy all fields")

                        Button { document.export(raw: mode == .raw) } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                        .help("Save the report to a text file")
                    }
                }
        }
    }
}

/// Custom filter bar. The toolbar toggle (⌘F) opens/closes it; the ✕ only clears
/// the text. Escape closes. Keeps "clear" and "close" visually distinct.
struct SearchBar: View {
    @Binding var text: String
    var onClose: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter fields", text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
                .onExitCommand(perform: onClose)   // Escape closes the bar
            if !text.isEmpty {
                Button { text = ""; focused = true } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .onAppear { focused = true }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.and.magnifyingglass")
                .font(.system(size: 52))
                .foregroundStyle(Color.mintAccent)
            Text("Drop a media file here")
                .font(.title3)
            Text("…or right-click any file → Open With → MINT")
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
