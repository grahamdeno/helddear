import Foundation

/// Which Lock Screen cards to show (Graham, Nov 22, 2026): a person's day while it's today, for the inner and
/// middle circles, until it's done; and something ordered that arrives in the next two days, until it's marked
/// ready. Plain rules, unit tested.
enum LiveDays {
    struct Day: Equatable {
        var id: UUID
        var title: String
        var dueDate: Date
        var ring: Ring
        var settled: Bool
        var personal: Bool
    }

    struct Arrival: Equatable {
        var id: UUID
        var title: String
        var arrives: Date
        var placed: Bool
        var ready: Bool
    }

    static let arrivalDays = 2

    static func days(_ all: [Day], now: Date, calendar: Calendar = .current) -> [Day] {
        all.filter { calendar.isDate($0.dueDate, inSameDayAs: now) && !$0.settled && $0.ring != .outer && $0.personal }
    }

    static func arrivals(_ all: [Arrival], now: Date, calendar: Calendar = .current) -> [Arrival] {
        all.filter { a in
            let days = OccasionDates.daysBetween(now, a.arrives, calendar: calendar)
            return a.placed && !a.ready && days >= 0 && days <= arrivalDays
        }
    }

    /// "Arrives today", "Arrives tomorrow", "Arrives Tuesday".
    static func arrivalLine(_ arrives: Date, now: Date, calendar: Calendar = .current) -> String {
        switch OccasionDates.daysBetween(now, arrives, calendar: calendar) {
        case 0: return "Arrives today"
        case 1: return "Arrives tomorrow"
        default: return "Arrives " + arrives.formatted(.dateTime.weekday(.wide))
        }
    }

    /// The end of the day a card is about: the card goes stale then.
    static func endOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
    }
}
