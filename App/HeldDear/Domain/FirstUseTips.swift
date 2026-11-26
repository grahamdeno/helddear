import Foundation

/// One-time tips: a single short line the first time someone reaches a new part of the app, then never again
/// (Graham, Nov 25, 2026: one thing at a time, only when it's needed). Kept on this iPhone. Plain rules, unit tested.
/// Rules (Fable's first-use audit): never two tips on one screen, and none during setup or in the Apple Pay flow.
enum FirstUseTip: String, CaseIterable {
    case home, plan, holiday, ideas, shareIdeas, widgets, rings, planLimit

    /// Wording approved by Graham one by one, Nov 25, 2026.
    var line: String {
        switch self {
        case .home: "The big name is whose day comes next. Tap it for the full page, or swipe to see who's after."
        case .plan: "A plan is the day in parts: a gift, a card, a cake. Tap a part to say who's doing it and where it stands."
        case .holiday: "Everyone you're planning for, on one page. Tap a name to open that plan."
        case .ideas: "Save an idea whenever one comes to you. It's on the person's page when the day gets close."
        case .shareIdeas: "Next time, share a link from Safari or a shop's app. If Held Dear isn't in the row, tap More."
        case .widgets: "Add a Held Dear widget to your Home Screen or Lock Screen to see who's coming up."
        case .rings: "The people you picked get a 3-week heads-up. Change it under Reminders on this page."
        case .planLimit: "This is the third of three free plans. Lifetime adds plans for everyone."
        }
    }

    /// The two tips about things outside Held Dear carry a small drawn picture (Graham, Nov 25, 2026).
    var hasPicture: Bool { self == .shareIdeas || self == .widgets }

    /// What VoiceOver reads for the picture.
    var pictureSteps: String? {
        switch self {
        case .shareIdeas: "In Safari or a shop's app, tap Share, then Held Dear. If it isn't there, tap More."
        case .widgets: "Press and hold your Home Screen, tap the plus button, then find Held Dear."
        default: nil
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

    /// One screen's tip: the first of `candidates` that is due and not yet seen, so a screen never shows two.
    static func pick(_ candidates: [(FirstUseTip, Bool)], _ defaults: UserDefaults = .standard) -> FirstUseTip? {
        candidates.first { $0.1 && shouldShow($0.0, defaults) }?.0
    }
}
