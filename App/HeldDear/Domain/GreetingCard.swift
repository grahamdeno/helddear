import Foundation

/// A digital card from the user to anyone (story 2.11, approved Nov 21, 2026): for a holiday, a reason, or just
/// their own words; one photo or a series; still or moving. Plain rules so they're unit tested.
enum GreetingCard {
    enum Occasion: Hashable, Identifiable {
        case holiday(OccasionType)
        case reason(CardReason)
        case ownWords

        var id: String {
            switch self {
            case .holiday(let t): "h-\(t.rawValue)"
            case .reason(let r): "r-\(r.rawValue)"
            case .ownWords: "own"
            }
        }

        var label: String {
            switch self {
            case .holiday(let t): t.label
            case .reason(let r): r.label
            case .ownWords: "Just my words"
            }
        }

        /// The heading it starts with; the user can change it.
        var heading: String {
            switch self {
            case .holiday(let t): String(t.cardOpening.dropLast())   // "Merry Christmas"
            case .reason(let r): Self.reasonHeading(r)
            case .ownWords: ""
            }
        }

        var holidayType: OccasionType? {
            if case .holiday(let t) = self { return t }
            return nil
        }

        private static func reasonHeading(_ r: CardReason) -> String {
            switch r {
            case .justBecause: "Thinking of you"
            case .getWell: "Feel better soon"
            case .thankYou: "Thank you"
            case .thinkingOfYou: "Thinking of you"
            case .congratulations: "Congratulations"
            case .sympathy: "With love"
            }
        }
    }

    /// What the card list offers: the holidays the user keeps, then the reasons, then their own words.
    static func choices(holidays: [OccasionType]) -> [Occasion] {
        holidays.map { .holiday($0) } + CardReason.allCases.map { .reason($0) } + [.ownWords]
    }

    /// "from Graham" from whatever the user signs with. Empty stays empty.
    static func signature(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : "from \(trimmed)"
    }

    static let maxPhotos = 10
    /// Each photo holds this long in the moving version, crossfading into the next.
    static let perPhoto: Double = 1.6

    /// When the words start rising: as the last photo comes in.
    static func wordsStart(photos: Int) -> Double {
        photos <= 1 ? 0.6 : Double(photos - 1) * perPhoto + 0.6
    }

    /// The whole moving version: the photos, then the words, then a short hold.
    static func duration(photos: Int) -> Double { wordsStart(photos: photos) + 3.4 }

    /// Which photo is showing at a moment, and how far it has faded in (0 to 1).
    static func slide(at t: Double, photos: Int) -> (index: Int, fade: Double) {
        guard photos > 0 else { return (0, 1) }
        let i = min(photos - 1, max(0, Int(t / perPhoto)))
        let into = t - Double(i) * perPhoto
        return (i, i == 0 ? 1 : min(1, max(0, into / 0.5)))
    }
}
