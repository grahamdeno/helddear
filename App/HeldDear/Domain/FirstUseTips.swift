import Foundation

/// One-time tips: a single short line the first time someone reaches a new part of the app, then never again
/// (Graham, Nov 25, 2026: one thing at a time, only when it's needed). Kept on this iPhone. Plain rules, unit tested.
enum FirstUseTip: String, CaseIterable {
    case home, plan, holiday, ideas, cardPicker, shareIdeas, widgets, rings

    /// Wording waits for Graham's read-back and the first-use audit; these are the drafts.
    var line: String {
        switch self {
        case .home: "Your year, left to right. Tap a name to open that person's page."
        case .plan: "A plan is the day in a few parts. Tap a part to say who's doing it."
        case .holiday: "Everyone's plan for this day, on one page. Tap a name to start that plan."
        case .ideas: "Save an idea when it comes to you. It waits on the person's page until the day."
        case .cardPicker: "Tap a card to pick it. Tap it again to see it up close."
        // Shown after the first idea is saved by hand: the share sheet can't be found from inside the app.
        case .shareIdeas: "Next time, share a link from Safari or any shop's app straight to Held Dear."
        // Shown after the first plan is done, with Lifetime.
        case .widgets: "Add Held Dear to your Home Screen or Lock Screen to see who's coming up."
        // Shown on the first person's page.
        case .rings: "Your closest people get a 3-week heads-up. Change it under Reminders on this page."
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
