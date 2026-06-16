import SwiftUI

/// Inspector display preferences, shared via @AppStorage.
enum Prefs {
    static let fontSizeKey = "fontSize"
    static let rowSpacingKey = "rowSpacing"
    static let fontSizeDefault = 13.0
    static let rowSpacingDefault = 5.0
    static let fontSizeRange = 11.0...20.0
    static let rowSpacingRange = 2.0...16.0
}

enum About {
    static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
    static let repoURL = URL(string: "https://github.com/yogiee/MINT")!
    static let mediaInfoURL = URL(string: "https://mediaarea.net/MediaInfo")!
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "textformat.size") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460)
    }
}

struct GeneralSettingsView: View {
    @AppStorage(Prefs.fontSizeKey) private var fontSize = Prefs.fontSizeDefault
    @AppStorage(Prefs.rowSpacingKey) private var rowSpacing = Prefs.rowSpacingDefault

    var body: some View {
        Form {
            Section("Inspector") {
                LabeledContent("Font size") {
                    HStack {
                        Slider(value: $fontSize, in: Prefs.fontSizeRange, step: 1)
                        Text("\(Int(fontSize)) pt").monospacedDigit()
                            .foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    }
                }
                LabeledContent("Row spacing") {
                    HStack {
                        Slider(value: $rowSpacing, in: Prefs.rowSpacingRange, step: 1)
                        Text("\(Int(rowSpacing)) pt").monospacedDigit()
                            .foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section("Preview") {
                VStack(spacing: 0) {
                    ForEach(Self.sample, id: \.0) { label, value in
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(label)
                                .font(.system(size: fontSize))
                                .frame(width: fontSize * 14, alignment: .leading)
                                .foregroundStyle(.secondary)
                            Text(value)
                                .font(.system(size: fontSize, design: .monospaced))
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, rowSpacing)
                    }
                }
            }

            Section {
                Button("Reset to Defaults") {
                    fontSize = Prefs.fontSizeDefault
                    rowSpacing = Prefs.rowSpacingDefault
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 420)
    }

    static let sample: [(String, String)] = [
        ("Format", "AVC"),
        ("Frame rate", "23.976 FPS"),
        ("Bit rate", "2 600 kb/s"),
    ]
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 96, height: 96)
            Text("MINT").font(.system(size: 28, weight: .semibold))
            Text("Media INformaTion").foregroundStyle(.secondary)
            Text("Version \(About.version)").font(.caption).foregroundStyle(.secondary)

            Divider().padding(.vertical, 4)

            Text("A fast, native viewer for full media file info.")
                .font(.callout).multilineTextAlignment(.center)
            Link("github.com/yogiee/MINT", destination: About.repoURL)
                .font(.callout)

            Divider().padding(.vertical, 4)

            VStack(spacing: 3) {
                Text("Powered by MediaInfo").font(.caption)
                Link("© MediaArea.net · BSD-2-Clause", destination: About.mediaInfoURL)
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text("© 2026 yogiee").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(width: 460, height: 420)
    }
}
