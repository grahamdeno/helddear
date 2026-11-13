import Foundation

/// The days to look in Photos for a person's past birthdays: the birthday itself and the weekend
/// party days around it (one day before, one after), for each past year. Newest first.
enum PhotoWindows {
    struct Window: Equatable {
        let year: Int
        let start: Date
        let end: Date
    }

    static func birthdays(month: Int, day: Int, now: Date, yearsBack: Int = 12, calendar: Calendar = .current) -> [Window] {
        let thisYear = calendar.component(.year, from: now)
        let today = calendar.startOfDay(for: now)
        var out: [Window] = []
        for year in stride(from: thisYear, through: thisYear - yearsBack, by: -1) {
            let date = OccasionDates.date(month: month, day: day, year: year, calendar: calendar)
            let start = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date))!
            let end = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: date))!
            // Only days that have fully passed or started.
            if start > today { continue }
            out.append(Window(year: year, start: start, end: min(end, calendar.date(byAdding: .day, value: 1, to: today)!)))
        }
        return out
    }
}
