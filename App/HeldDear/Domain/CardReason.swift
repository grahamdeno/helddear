import Foundation

/// A card for any reason, not only a day (story 2.8, approved Nov 21, 2026).
enum CardReason: String, CaseIterable, Identifiable {
    case justBecause, getWell, thankYou, thinkingOfYou, congratulations, sympathy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .justBecause: "Just because"
        case .getWell: "Get well"
        case .thankYou: "Thank you"
        case .thinkingOfYou: "Thinking of you"
        case .congratulations: "Congratulations"
        case .sympathy: "Sorry for your loss"
        }
    }

    /// The card's opening line, before the name.
    var opening: String {
        switch self {
        case .justBecause: "Thinking of you,"
        case .getWell: "Feel better soon,"
        case .thankYou: "Thank you,"
        case .thinkingOfYou: "Thinking of you,"
        case .congratulations: "Congratulations,"
        case .sympathy: "With love and sympathy,"
        }
    }

    func greeting(name: String) -> String {
        switch self {
        case .sympathy: "\(opening) \(name)."
        default: "\(opening) \(name)!"
        }
    }

    /// The key sent to the card server so it can show this reason's designs. Until the server knows a key it
    /// shows its fallback designs.
    var serverKey: String { rawValue }

    /// "just-because", "get-well": the kind of card, in a sentence.
    var kind: String {
        switch self {
        case .justBecause: "just-because"
        case .getWell: "get-well"
        case .thankYou: "thank-you"
        case .thinkingOfYou: "thinking-of-you"
        case .congratulations: "congratulations"
        case .sympathy: "sympathy"
        }
    }

    /// The yearly record's line: "Get-well card, Nov 21".
    func recordLine(on date: Date) -> String {
        let what = kind.prefix(1).uppercased() + kind.dropFirst()
        return "\(what) card, \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    /// A mailed one: "Handwritten get-well card, mailed Nov 21".
    func mailedRecordLine(on date: Date) -> String {
        "Handwritten \(kind) card, mailed \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }
}
