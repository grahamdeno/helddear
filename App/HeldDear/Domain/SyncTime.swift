import Foundation

/// How the iCloud status page says when something last went up or came down (Graham, Nov 24, 2026): one line each,
/// "today at 1:17 PM", "yesterday at 9:02 AM", or "Nov 20 at 4:15 PM". Plain rules, unit tested.
enum SyncTime {
    static func line(_ date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
        if calendar.isDate(date, inSameDayAs: now) { return "today at \(time)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "yesterday at \(time)"
        }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let day = date.formatted(sameYear ? Date.FormatStyle().month(.abbreviated).day().locale(locale)
                                          : Date.FormatStyle().month(.abbreviated).day().year().locale(locale))
        return "\(day) at \(time)"
    }
}
