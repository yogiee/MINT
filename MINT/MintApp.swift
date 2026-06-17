import SwiftUI

@main
struct MintApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var recents = RecentStore()   // shared across all windows
    private let updater = UpdaterService.shared         // starts Sparkle at launch

    var body: some Scene {
        // Each window owns its own state, so multiple windows are fully
        // independent (open different files and compare side by side).
        WindowGroup(id: "main") {
            WindowRoot()
                .environmentObject(recents)
                .environmentObject(delegate)
                .frame(minWidth: 560, minHeight: 380)
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 820, height: 580)
        // Don't reopen last session's files (often temp/deleted); Open-With drives windows.
        .restorationBehavior(.disabled)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    UpdaterService.shared.checkForUpdates()
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}
