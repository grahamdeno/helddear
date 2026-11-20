import Foundation

/// The calm note on a plan about what's still open, and the one button under it (roadmap story 2.4).
/// Plain rules. Never red, never a badge.
enum PlanNudge {
    struct Part: Equatable {
        /// The part's display name.
        var name: String
        /// True when the user typed the name, so it is not lowercased inside a sentence.
        var typed: Bool = false
        var family: PartSteps.Family
        var step: String

        var isNotStarted: Bool { step == "open" }
    }

    struct Result: Equatable {
        /// The note above the rows; nil when nothing is open.
        var note: String?
        /// "Plan the cake", or "Everything is planned".
        var buttonTitle: String
        /// Index (in the parts given) of the part the button opens; nil when nothing is open.
        var target: Int?

        var isEnabled: Bool { target != nil }
    }

    /// Days before the day by which a part should be under way. Nil for a call or message, which have no lead time.
    static func leadDays(for family: PartSteps.Family) -> Int? {
        switch family {
        case .orderAhead: 7
        case .buy: 14
        case .card: OccasionDates.cutoffDays
        case .make, .day, .other: 7
        case .callOrMessage: nil
        }
    }

    /// The first half of the sentence about a part that is outside its lead time.
    static func usualLine(for family: PartSteps.Family) -> String {
        switch family {
        case .orderAhead: "Usually ordered about a week ahead,"
        case .buy: "Gifts usually take a week or two to arrive,"
        case .card: "Cards go in the mail about five days ahead,"
        case .make, .day, .other, .callOrMessage: "There's usually a week of planning,"
        }
    }

    /// What the part needs this week, once it is inside its lead time.
    static func needsWord(for family: PartSteps.Family) -> String {
        switch family {
        case .orderAhead: "ordering"
        case .buy: "buying"
        case .card: "mailing"
        case .make, .day, .other, .callOrMessage: "planning"
        }
    }

    /// `parts` are in plan order. `daysLeft` is whole days from today to the day (0 on the day).
    /// Everything keys off the first part that isn't started.
    static func make(parts: [Part], daysLeft: Int) -> Result {
        let open = parts.enumerated().filter { $0.element.isNotStarted }
        guard let first = open.first else {
            return Result(note: nil, buttonTitle: "Everything is planned", target: nil)
        }
        let part = first.element
        let button = "Plan the \(inSentence(part))"
        let inside = leadDays(for: part.family).map { daysLeft <= $0 } ?? false
        if inside {
            return Result(note: "\(part.name) needs \(needsWord(for: part.family)) this week.",
                          buttonTitle: button, target: first.offset)
        }
        let usual = "\(usualLine(for: part.family)) so there's time."
        let lead: String
        switch open.count {
        case 1: lead = "\(part.name) isn't started yet."
        case 2: lead = "\(part.name) and \(open[1].element.name) aren't started yet."
        default: lead = "\(part.name), \(open[1].element.name) and \(open.count - 2) more aren't started yet."
        }
        return Result(note: "\(lead) \(usual)", buttonTitle: button, target: first.offset)
    }

    /// A part's name inside a sentence: the kind's own names start with a lowercase letter; typed names stay as typed.
    static func inSentence(_ part: Part) -> String {
        guard !part.typed, let f = part.name.first else { return part.name }
        return f.lowercased() + part.name.dropFirst()
    }
}
