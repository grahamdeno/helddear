import Foundation

/// When Held Dear starts looking for a gift, and the dates it suggests. Plain Swift, unit tested.
enum GiftTiming {
    /// Ideas come forward this many days before the day: early enough for slow shipping and things that sell out.
    static let ideasWindowDays = 42

    /// True when the day is close enough to start finding something (and not today or past).
    static func isIdeaTime(due: Date, now: Date, calendar: Calendar = .current) -> Bool {
        let days = OccasionDates.daysBetween(now, due, calendar: calendar)
        return days > 0 && days <= ideasWindowDays
    }

    /// The arrival date to aim for: five days before the day, never before tomorrow.
    static func suggestedArrival(due: Date, now: Date, calendar: Calendar = .current) -> Date {
        let target = OccasionDates.adding(days: -5, to: due, calendar: calendar)
        let tomorrow = OccasionDates.adding(days: 1, to: calendar.startOfDay(for: now), calendar: calendar)
        return max(target, min(tomorrow, due))
    }

    /// How many saved ideas came in during the last year, for "You saved 2 ideas this year".
    static func savedThisYear(_ dates: [Date], now: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.date(byAdding: .year, value: -1, to: now)!
        return dates.filter { $0 >= start && $0 <= now }.count
    }
}
