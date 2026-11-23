import Foundation

/// The message sent on a person's day, written ahead of time (Graham, Nov 22, 2026): write it, read it on their page,
/// change it, or go back to the usual greeting. Kept on this phone by the day's id; the day-of message and card use it.
enum DayMessages {
    private static let key = "dayMessages"

    static func message(for momentID: UUID, _ d: UserDefaults = .standard) -> String? {
        ((d.dictionary(forKey: key) as? [String: String]) ?? [:])[momentID.uuidString]
    }

    /// Saves the message; an empty one, or one that's just the usual greeting, goes back to the usual.
    static func set(_ text: String?, for momentID: UUID, usual: String, _ d: UserDefaults = .standard) {
        var all = (d.dictionary(forKey: key) as? [String: String]) ?? [:]
        let t = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        all[momentID.uuidString] = t.isEmpty || t == usual ? nil : t
        d.set(all, forKey: key)
    }

    /// What goes out: the saved message, or the usual greeting.
    static func text(for momentID: UUID, usual: String, _ d: UserDefaults = .standard) -> String {
        message(for: momentID, d) ?? usual
    }
}
