import Foundation

/// Other dates on a person's contact card, like an anniversary, offered as days to add (Graham, Nov 21, 2026).
/// Contacts are only read. Plain rules, unit tested.
struct ContactDate: Equatable, Identifiable {
    /// The contact's own label, like "anniversary" or "Graduation".
    var label: String
    var isAnniversary: Bool
    var month: Int
    var day: Int
    var year: Int?

    var id: String { "\(label)-\(month)-\(day)" }
}

enum ContactDates {
    /// What the day would be called in Held Dear: "Anniversary", or the contact's label in sentence case.
    static func title(_ d: ContactDate) -> String {
        if d.isAnniversary { return "Anniversary" }
        let trimmed = d.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "A day" : trimmed.prefix(1).uppercased() + trimmed.dropFirst()
    }

    /// The contact's dates not already in Held Dear. A date is already there when a day of the same kind falls on
    /// the same month and day (any anniversary for an anniversary; for anything else, any day but the birthday).
    static func offers(_ dates: [ContactDate], existing: [(type: OccasionType, month: Int, day: Int)]) -> [ContactDate] {
        var seen = Set<String>()
        return dates.filter { d in
            guard (1...12).contains(d.month), (1...31).contains(d.day), seen.insert(d.id).inserted else { return false }
            return !existing.contains { e in
                e.month == d.month && e.day == d.day && (d.isAnniversary ? e.type == .anniversary : e.type != .birthday)
            }
        }
    }
}
