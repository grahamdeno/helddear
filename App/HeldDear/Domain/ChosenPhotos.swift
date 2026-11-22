import Foundation

/// Photos the user chose for a person (Graham, Nov 21, 2026): Held Dear no longer looks through the library. A chosen
/// photo keeps the day it was taken in its file name ("…_d20230805.jpg"), so the person's past birthdays can show the
/// photos from those days. Removing a photo deletes it from Held Dear only; the library isn't touched.
enum ChosenPhotos {
    struct Year: Identifiable, Equatable {
        let year: Int
        let files: [String]
        var id: Int { year }
    }

    /// The file name for a new photo taken on `date` (or with no date).
    static func fileName(id: String = UUID().uuidString, taken date: Date?, calendar: Calendar = .current) -> String {
        guard let date else { return id + ".jpg" }
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%@_d%04d%02d%02d.jpg", id, c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// The day a photo was taken, from its file name.
    static func taken(_ file: String, calendar: Calendar = .current) -> Date? {
        guard let r = file.range(of: #"_d(\d{8})\."#, options: .regularExpression) else { return nil }
        let digits = file[r].dropFirst(2).prefix(8)
        guard let y = Int(digits.prefix(4)), let m = Int(digits.dropFirst(4).prefix(2)), let d = Int(digits.suffix(2)) else { return nil }
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))
    }

    /// Past birthdays that have chosen photos, newest first: photos taken the day before, on, or after the birthday.
    static func birthdayYears(files: [String], month: Int, day: Int, now: Date = Date(), calendar: Calendar = .current) -> [Year] {
        let thisYear = calendar.component(.year, from: now)
        return PhotoWindows.birthdays(month: month, day: day, now: now, yearsBack: 40, calendar: calendar)
            .filter { $0.year < thisYear }
            .compactMap { w in
                let inside = files.filter { f in taken(f, calendar: calendar).map { $0 >= w.start && $0 < w.end } ?? false }
                return inside.isEmpty ? nil : Year(year: w.year, files: inside)
            }
    }

    /// Picking a whole album (Graham, Nov 22, 2026): every photo taken near one of the person's days is kept, so
    /// past birthdays fill in, plus up to `others` more, in the order picked. The rest aren't copied in, so a big
    /// album doesn't fill the phone or iCloud.
    static func keep(taken: [Date?], days: [(month: Int, day: Int)], within window: Int = 3, others: Int = 30,
                     calendar: Calendar = .current) -> [Bool] {
        var extra = 0
        return taken.map { date in
            if let date, nearDay(date, days: days, within: window, calendar: calendar) { return true }
            guard extra < others else { return false }
            extra += 1
            return true
        }
    }

    static func nearDay(_ date: Date, days: [(month: Int, day: Int)], within window: Int, calendar: Calendar = .current) -> Bool {
        let year = calendar.component(.year, from: date)
        let start = calendar.startOfDay(for: date)
        for d in days {
            for y in [year - 1, year, year + 1] {
                guard let day = calendar.date(from: DateComponents(year: y, month: d.month, day: d.day)) else { continue }
                let gap = abs(calendar.dateComponents([.day], from: start, to: day).day ?? 999)
                if gap <= window { return true }
            }
        }
        return false
    }
}

