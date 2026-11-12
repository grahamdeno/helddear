import Foundation

/// Date rules from the screen spec: alerts at 9:00 a.m. local, order-by and mail-by 5 days before,
/// February 29 observed on February 28 in non-leap years.
enum OccasionDates {
    static let alertHour = 9
    static let cutoffDays = 5
    static let wishPromptDays = 60

    /// The calendar date (start of day) of a fixed-day occasion in a given year.
    static func date(month: Int, day: Int, year: Int, calendar: Calendar = .current) -> Date {
        var d = day
        if month == 2 && day == 29 && !isLeap(year) { d = 28 }
        let comps = DateComponents(year: year, month: month, day: d)
        return calendar.startOfDay(for: calendar.date(from: comps) ?? Date())
    }

    static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    /// The one occurrence in a 12-month window that starts 4 days ago
    /// (so a just-passed birthday can still be handled as missed).
    static func occurrences(month: Int, day: Int, from start: Date, calendar: Calendar = .current) -> [(year: Int, date: Date)] {
        let today = calendar.startOfDay(for: start)
        let windowStart = calendar.date(byAdding: .day, value: -4, to: today)!
        let windowEnd = calendar.date(byAdding: .month, value: 12, to: windowStart)!
        let year = calendar.component(.year, from: today)
        return (year - 1...year + 1).compactMap { y in
            let d = date(month: month, day: day, year: y, calendar: calendar)
            return (d >= windowStart && d < windowEnd) ? (y, d) : nil
        }
    }

    /// The next occurrence on or after the given day.
    static func nextDate(month: Int, day: Int, onOrAfter start: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: start)
        let year = calendar.component(.year, from: today)
        let this = date(month: month, day: day, year: year, calendar: calendar)
        return this >= today ? this : date(month: month, day: day, year: year + 1, calendar: calendar)
    }

    /// 9:00 a.m. on the given day.
    static func alertTime(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: alertHour, minute: 0, second: 0, of: calendar.startOfDay(for: day))!
    }

    static func adding(days: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!
    }

    /// The next 9:00 a.m. strictly after `now`.
    static func nextMorning(after now: Date, calendar: Calendar = .current) -> Date {
        let today9 = alertTime(on: now, calendar: calendar)
        return today9 > now ? today9 : adding(days: 1, to: today9, calendar: calendar)
    }

    static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    /// "Today", "Tomorrow", "in 9 days", "in 2 months", "Yesterday".
    static func countdown(to due: Date, from now: Date, calendar: Calendar = .current) -> String {
        let days = daysBetween(now, due, calendar: calendar)
        switch days {
        case ..<(-1): return "\(-days) days ago"
        case -1: return "Yesterday"
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...45:
            return "in \(days) days"
        default:
            let months = max(1, Int((Double(days) / 30.4).rounded()))
            return months == 1 ? "in 1 month" : "in \(months) months"
        }
    }

    /// The age someone turns on this occurrence, when a birth year is known.
    static func turning(birthYear: Int?, occurrenceYear: Int) -> Int? {
        guard let birthYear, birthYear > 1900, occurrenceYear > birthYear else { return nil }
        return occurrenceYear - birthYear
    }

    static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day())
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}
