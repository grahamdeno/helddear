import Foundation

/// The share image for a person's day (approved Nov 21, 2026): the photo, the name, one line, and Home's timeline
/// with a dot on the day. Plain rules here so they're unit tested. Age and birth year are never shown unless the
/// user turns on "Add age" for that one image: a post can be seen by anyone.
enum ShareCardLayout {
    /// Seven months on the line, the day's month in the middle: Sep to Mar for a December day.
    static func months(around date: Date, calendar: Calendar = .current) -> [Date] {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        return (-3...3).map { calendar.date(byAdding: .month, value: $0, to: start)! }
    }

    /// Where the day sits on the line, 0 at the start of the first month and 1 at the end of the last.
    static func position(of date: Date, calendar: Calendar = .current) -> Double {
        let day = Double(calendar.component(.day, from: date))
        let days = Double(calendar.range(of: .day, in: .month, for: date)?.count ?? 30)
        return (3 + (day - 0.5) / days) / 7
    }

    /// The line under the name: "birthday", or "turns 40" with age added. A named day uses its name.
    static func subline(type: OccasionType, partner: String?, count: Int?, addAge: Bool) -> String {
        if addAge, let line = type.countLine(count) { return line.prefix(1).lowercased() + line.dropFirst() }
        switch type {
        case .anniversary: return "anniversary"
        case .event, .custom: return type.title(partner: partner)
        default: return type.label.lowercased()
        }
    }

    /// "Dec 17", the label above the dot.
    static func dotLabel(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// The moving version's timing, in seconds: the line draws, the dot lands on the day, the name rises, then it
    /// holds. The still image is the last frame.
    static let duration: Double = 6.0

    // MARK: Several photos (Graham, Nov 22, 2026: the same slideshow and ending as the digital card)

    /// Up to five photos, so the moving version stays under 13 seconds (a Story's length).
    static let maxPhotos = 5

    /// How long the slideshow runs before the line starts drawing: each photo but the last holds for the digital
    /// card's beat. One photo: no slideshow.
    static func lead(photos: Int) -> Double { photos <= 1 ? 0 : Double(photos - 1) * GreetingCard.perPhoto }

    /// The whole moving version: the slideshow, then the line, the dot and the words.
    static func duration(photos: Int) -> Double { lead(photos: photos) + duration }

    /// Tapping a photo in the row: adds it at the end (until the limit), or takes it out. The order is the order of
    /// the slideshow, and the first is the still card's photo.
    static func toggled(_ picked: [Int], _ index: Int, max: Int = maxPhotos) -> [Int] {
        if let at = picked.firstIndex(of: index) {
            var out = picked
            out.remove(at: at)
            return out
        }
        return picked.count >= max ? picked : picked + [index]
    }

    static func ramp(_ t: Double, from a: Double, to b: Double) -> Double {
        guard b > a else { return t >= b ? 1 : 0 }
        let x = min(1, max(0, (t - a) / (b - a)))
        return 1 - pow(1 - x, 3)
    }
}
