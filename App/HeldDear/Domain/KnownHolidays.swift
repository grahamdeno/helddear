import Foundation

/// Holidays Held Dear can date by itself when the user adds one (Graham, Nov 22, 2026). Dates come from the
/// calendars built into iOS (Hebrew, Chinese, Islamic) or a simple rule, never from a table of dates. A holiday
/// whose date it can't work out (Diwali) is still suggested by name, and the user picks the day.
struct KnownHoliday: Equatable {
    var name: String
    enum Rule: Equatable {
        /// Same day every year.
        case fixed(month: Int, day: Int)
        /// A month and day in another calendar.
        case calendar(Calendar.Identifier, month: Int, day: Int)
        /// The Sunday after the first Monday in September (US Grandparents Day).
        case grandparentsDay
        /// Moves every year and isn't worked out here.
        case pickDay
    }
    var rule: Rule

    /// The next time it falls on or after `from`, or nil when the user picks the day.
    func nextDate(onOrAfter from: Date, calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: from)
        switch rule {
        case .fixed(let m, let d):
            return OccasionDates.nextDate(month: m, day: d, onOrAfter: start, calendar: calendar)
        case .calendar(let id, let m, let d):
            var other = Calendar(identifier: id)
            other.timeZone = calendar.timeZone
            let probe = calendar.date(byAdding: .day, value: -1, to: start) ?? start
            guard let found = other.nextDate(after: probe, matching: DateComponents(month: m, day: d),
                                             matchingPolicy: .nextTime) else { return nil }
            return calendar.startOfDay(for: found)
        case .grandparentsDay:
            let year = calendar.component(.year, from: start)
            for y in [year, year + 1] {
                if let d = Self.grandparentsDay(year: y, calendar: calendar), d >= start { return d }
            }
            return nil
        case .pickDay:
            return nil
        }
    }

    static func grandparentsDay(year: Int, calendar: Calendar) -> Date? {
        guard let sept1 = calendar.date(from: DateComponents(year: year, month: 9, day: 1)) else { return nil }
        let weekday = calendar.component(.weekday, from: sept1)   // 1 = Sunday, 2 = Monday
        let toMonday = (2 - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: toMonday + 6, to: sept1)
    }
}

enum KnownHolidays {
    static let all: [KnownHoliday] = [
        KnownHoliday(name: "Hanukkah", rule: .calendar(.hebrew, month: 3, day: 25)),
        KnownHoliday(name: "Rosh Hashanah", rule: .calendar(.hebrew, month: 1, day: 1)),
        KnownHoliday(name: "Lunar New Year", rule: .calendar(.chinese, month: 1, day: 1)),
        KnownHoliday(name: "Eid al-Fitr", rule: .calendar(.islamicUmmAlQura, month: 10, day: 1)),
        KnownHoliday(name: "Eid al-Adha", rule: .calendar(.islamicUmmAlQura, month: 12, day: 10)),
        KnownHoliday(name: "Diwali", rule: .pickDay),
        KnownHoliday(name: "Easter", rule: .pickDay),
        KnownHoliday(name: "Grandparents Day", rule: .grandparentsDay),
        KnownHoliday(name: "Kwanzaa", rule: .fixed(month: 12, day: 26)),
        KnownHoliday(name: "St. Patrick's Day", rule: .fixed(month: 3, day: 17)),
        KnownHoliday(name: "Halloween", rule: .fixed(month: 10, day: 31)),
        KnownHoliday(name: "New Year's Day", rule: .fixed(month: 1, day: 1)),
    ]

    /// Names that start with what's typed, then names that contain it.
    static func matches(_ query: String) -> [KnownHoliday] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        let starts = all.filter { $0.name.lowercased().hasPrefix(q) }
        let contains = all.filter { !$0.name.lowercased().hasPrefix(q) && $0.name.lowercased().contains(q) }
        return starts + contains
    }

    static func named(_ name: String) -> KnownHoliday? {
        all.first { $0.name.caseInsensitiveCompare(name.trimmingCharacters(in: .whitespaces)) == .orderedSame }
    }
}
