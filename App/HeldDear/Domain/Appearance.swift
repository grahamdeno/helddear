import SwiftUI

/// Light, dark or the iPhone's own setting (Graham, Nov 24, 2026). Saved on this iPhone; Held Dear follows the iPhone
/// until the person picks Light or Dark in You > Appearance.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    static let key = "appearance"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Match iPhone"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// nil follows the iPhone.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    static func from(_ raw: String) -> Appearance { Appearance(rawValue: raw) ?? .system }
}
