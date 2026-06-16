import SwiftUI
import AppKit

/// Light / Dark / System color-mode preference, persisted across launches.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    /// nil = follow the system setting.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }

    /// Apply to the whole app. Driving `NSApp.appearance` (rather than SwiftUI's
    /// `.preferredColorScheme`) reliably reverts to System — `.preferredColorScheme(nil)`
    /// leaves content stuck in the previous scheme's colors.
    func apply() {
        NSApp.appearance = nsAppearance
    }
}

extension Color {
    /// MINT's single accent — mint green (#34D399).
    static let mintAccent = Color(red: 0.204, green: 0.827, blue: 0.600)
}
