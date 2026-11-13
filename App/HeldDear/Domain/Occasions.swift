import Foundation

/// Every kind of occasion Held Dear keeps. Birthdays and anniversaries repeat on a date;
/// holidays repeat on a fixed date or a rule (Mother's Day); life moments happen once.
enum OccasionType: String, Codable, CaseIterable, Identifiable {
    case birthday, anniversary
    case christmas, valentines, mothersDay, fathersDay
    case newBaby, graduation, newHome, retirement

    var id: String { rawValue }

    enum Kind { case yearly, holiday, once }

    var kind: Kind {
        switch self {
        case .birthday, .anniversary: .yearly
        case .christmas, .valentines, .mothersDay, .fathersDay: .holiday
        case .newBaby, .graduation, .newHome, .retirement: .once
        }
    }

    var label: String {
        switch self {
        case .birthday: "Birthday"
        case .anniversary: "Anniversary"
        case .christmas: "Christmas"
        case .valentines: "Valentine's Day"
        case .mothersDay: "Mother's Day"
        case .fathersDay: "Father's Day"
        case .newBaby: "New baby"
        case .graduation: "Graduation"
        case .newHome: "New home"
        case .retirement: "Retirement"
        }
    }

    /// Holidays know their own date; everything else asks for one.
    var needsDate: Bool { kind != .holiday }

    /// Fixed holiday dates. Mother's and Father's Day are computed per year.
    var fixedHoliday: (month: Int, day: Int)? {
        switch self {
        case .christmas: (12, 25)
        case .valentines: (2, 14)
        default: nil
        }
    }

    /// "Mom's birthday", "Mom & Dad's anniversary", "Mother's Day for Mom", "Sam's graduation".
    func subject(name: String, partner: String? = nil) -> String {
        switch self {
        case .birthday: return "\(name)'s birthday"
        case .anniversary:
            return partner.map { "\(name) & \($0)'s anniversary" } ?? "\(name)'s anniversary"
        case .christmas, .valentines, .mothersDay, .fathersDay: return "\(label) for \(name)"
        case .newBaby: return "\(name)'s new baby"
        case .graduation: return "\(name)'s graduation"
        case .newHome: return "\(name)'s new home"
        case .retirement: return "\(name)'s retirement"
        }
    }

    /// The opening words on a card, before the name: "Happy birthday,".
    var cardOpening: String {
        switch self {
        case .birthday: "Happy birthday,"
        case .anniversary: "Happy anniversary,"
        case .christmas: "Merry Christmas,"
        case .valentines: "Happy Valentine's Day,"
        case .mothersDay: "Happy Mother's Day,"
        case .fathersDay: "Happy Father's Day,"
        case .newBaby, .graduation: "Congratulations,"
        case .newHome: "Welcome home,"
        case .retirement: "Happy retirement,"
        }
    }

    /// The day-of message: "Happy birthday, Mom!".
    func greeting(name: String) -> String { "\(cardOpening) \(name)!" }

    /// What the count means on this occurrence: "Turns 68", "40th anniversary". Nil when there's no count.
    func countLine(_ n: Int?) -> String? {
        guard let n else { return nil }
        switch self {
        case .birthday: return "Turns \(n)"
        case .anniversary: return "\(Self.ordinal(n)) anniversary"
        default: return nil
        }
    }

    /// The year field means a birth year, a first year together, or the year a one-time event happens.
    var yearLabel: String {
        switch self {
        case .birthday: "I know the year"
        case .anniversary: "I know the year they married"
        default: "Year"
        }
    }

    /// Life moments: a card or gift is the point, so they never need a call on the day.
    var isLifeMoment: Bool { kind == .once }

    static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 10, n % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}

/// When each occasion falls, using the same 12-month window as birthdays (starting 4 days back).
enum OccasionRules {
    static func date(type: OccasionType, month: Int, day: Int, year: Int, calendar: Calendar = .current) -> Date? {
        switch type {
        case .mothersDay: return nthWeekday(2, weekday: 1, month: 5, year: year, calendar: calendar)   // 2nd Sunday of May
        case .fathersDay: return nthWeekday(3, weekday: 1, month: 6, year: year, calendar: calendar)   // 3rd Sunday of June
        default:
            if let f = type.fixedHoliday { return OccasionDates.date(month: f.month, day: f.day, year: year, calendar: calendar) }
            return OccasionDates.date(month: month, day: day, year: year, calendar: calendar)
        }
    }

    /// Occurrences inside the window. A one-time event only counts in its own year.
    static func occurrences(type: OccasionType, month: Int, day: Int, year eventYear: Int?, from start: Date,
                            calendar: Calendar = .current) -> [(year: Int, date: Date)] {
        let today = calendar.startOfDay(for: start)
        let windowStart = calendar.date(byAdding: .day, value: -4, to: today)!
        let windowEnd = calendar.date(byAdding: .month, value: 12, to: windowStart)!
        let year = calendar.component(.year, from: today)
        let years: [Int]
        if type.kind == .once {
            guard let eventYear else { return [] }
            years = [eventYear]
        } else {
            years = Array(year - 1...year + 1)
        }
        return years.compactMap { y in
            guard let d = date(type: type, month: month, day: day, year: y, calendar: calendar) else { return nil }
            return (d >= windowStart && d < windowEnd) ? (y, d) : nil
        }
    }

    /// The count on an occurrence: age for birthdays, years together for anniversaries.
    static func count(type: OccasionType, startYear: Int?, occurrenceYear: Int) -> Int? {
        switch type {
        case .birthday, .anniversary: OccasionDates.turning(birthYear: startYear, occurrenceYear: occurrenceYear)
        default: nil
        }
    }

    static func nthWeekday(_ n: Int, weekday: Int, month: Int, year: Int, calendar: Calendar) -> Date? {
        var c = DateComponents(year: year, month: month)
        c.weekday = weekday
        c.weekdayOrdinal = n
        return calendar.date(from: c).map { calendar.startOfDay(for: $0) }
    }
}
