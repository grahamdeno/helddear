import Foundation

/// When a mailed card should arrive, and whether it makes Christmas (Nov 24, 2026). Handwrytten writes and mails in
/// 1 to 3 business days; USPS First-Class then takes 2 to 7 days. The Christmas order-by date comes from the server
/// (Dec 13 by default: Handwrytten says Dec 14). Plain rules, unit tested; views never work this out themselves.
enum MailArrival {
    static func estimate(orderedOn day: Date, calendar: Calendar = .current) -> (earliest: Date, latest: Date) {
        let start = calendar.startOfDay(for: day)
        let early = addBusinessDays(1, to: start, calendar: calendar)
        let late = addBusinessDays(3, to: start, calendar: calendar)
        return (calendar.date(byAdding: .day, value: 2, to: early)!, calendar.date(byAdding: .day, value: 7, to: late)!)
    }

    static func addBusinessDays(_ n: Int, to day: Date, calendar: Calendar) -> Date {
        var date = day, left = n
        while left > 0 {
            date = calendar.date(byAdding: .day, value: 1, to: date)!
            if !calendar.isDateInWeekend(date) { left -= 1 }
        }
        return date
    }

    /// "Arrives about Dec 3 to Dec 11."
    static func arrivalLine(orderedOn day: Date, calendar: Calendar = .current) -> String {
        let e = estimate(orderedOn: day, calendar: calendar)
        let f = Date.FormatStyle(timeZone: calendar.timeZone).month(.abbreviated).day()
        return "Arrives about \(e.earliest.formatted(f)) to \(e.latest.formatted(f))."
    }

    /// The Christmas line, from Nov 15 to Dec 31 only; nil the rest of the year or without an order-by date.
    static func christmasLine(today: Date, orderBy: Date?, calendar: Calendar = .current) -> String? {
        guard let orderBy else { return nil }
        let c = calendar.dateComponents([.month, .day], from: today)
        guard (c.month == 11 && (c.day ?? 0) >= 15) || c.month == 12 else { return nil }
        let f = Date.FormatStyle(timeZone: calendar.timeZone).month(.abbreviated).day()
        if calendar.startOfDay(for: today) <= calendar.startOfDay(for: orderBy) {
            return "Order by \(orderBy.formatted(f)) for Christmas."
        }
        return "Cards ordered now arrive after Christmas."
    }

    /// The server's "2026-12-13", read in the person's own calendar.
    static func day(fromISO text: String?, calendar: Calendar = .current) -> Date? {
        guard let text, text.count == 10 else { return nil }
        let p = text.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }
}
