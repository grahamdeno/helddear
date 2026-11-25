import Foundation

/// One-time tips: a single short line the first time someone reaches a new part of the app, then never again
/// (Graham, Nov 25, 2026: one thing at a time, only when it's needed). Kept on this iPhone. Plain rules, unit tested.
enum FirstUseTip: String, CaseIterable {
    case home, plan, holiday, ideas, cardPicker

    /// Wording waits for Graham's read-back and the first-use audit; these are the drafts.
    var line: String {
        switch self {
        case .home: "Your year, left to right. Tap a name to open their page."
        case .plan: "A plan is the day in a few parts. Tap a part to say who's doing it."
        case .holiday: "Everyone's plan for this day, on one page. Tap a name to plan for them."
        case .ideas: "Save an idea when it comes to you. You can also share a link here from any app."
        case .cardPicker: "Tap a card to pick it. Tap it again to see it up close."
        }
    }
}

enum FirstUseTips {
    static let prefix = "tipSeen."

    static func shouldShow(_ tip: FirstUseTip, _ defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: prefix + tip.rawValue)
    }

    static func markSeen(_ tip: FirstUseTip, _ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: prefix + tip.rawValue)
    }

    /// For You > How Held Dear works: show every tip again.
    static func resetAll(_ defaults: UserDefaults = .standard) {
        for t in FirstUseTip.allCases { defaults.removeObject(forKey: prefix + t.rawValue) }
    }
}
