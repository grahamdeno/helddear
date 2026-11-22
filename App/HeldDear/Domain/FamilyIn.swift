import Foundation

/// "Get the family in" (Graham, Nov 22, 2026): two weeks before a day that matters, Held Dear suggests asking the
/// people the user picked for that person, one text each, either to add a note to the family page or to send a card.
/// Plain rules, unit tested. The user taps Send on every message; the app never sends a text by itself. Before any
/// message, the user confirms who gets one, every time: the saved list is never used without that screen.
enum FamilyIn {
    /// The suggestion arrives two weeks out: time for a mailed card to arrive.
    static let promptDays = 14
    /// One follow-up for the people asked to send a card, three days out. Never more than one.
    static let followUpDays = 3
    /// The suggestion stays on the person's page until two days before (notes need a day to gather).
    static let lastDay = 2

    enum Choice: String, Codable { case notes, card }

    /// On for the inner circle unless the user turned it off; off elsewhere unless turned on.
    static func isOn(ring: Ring, override: Bool?) -> Bool { override ?? (ring == .inner) }

    /// Whether the suggestion shows on the person's page.
    static func showsSuggestion(daysLeft: Int, on: Bool, handled: Bool) -> Bool {
        on && !handled && daysLeft <= promptDays && daysLeft >= lastDay
    }

    /// Whether the one follow-up shows: only after a card reminder, only once, in the last three days.
    static func showsFollowUp(daysLeft: Int, cardAskSent: Bool, followedUp: Bool) -> Bool {
        cardAskSent && !followedUp && daysLeft <= followUpDays && daysLeft >= 1
    }

    /// "Saturday, January 9"
    static func dayText(_ date: Date) -> String { date.formatted(.dateTime.weekday(.wide).month(.wide).day()) }

    /// Personal days only: a birthday, an anniversary, a graduation and the like. Not shared holidays.
    static func applies(to occasion: OccasionType) -> Bool {
        switch occasion {
        case .christmas, .valentines, .mothersDay, .fathersDay, .custom: return false
        default: return true
        }
    }

    /// The note invitation, in the user's voice. Editable in Messages before sending. `subject` is "Josie's birthday".
    static func notesText(subject: String, name: String, date: Date, link: String) -> String {
        "I'm gathering notes for \(subject) on \(dayText(date)). Add yours here, no app needed. "
            + "\(name) sees them all on the day. \(link)"
    }

    /// The card reminder, with the mailing address when one is known.
    static func cardText(subject: String, name: String, date: Date, address: String?) -> String {
        var text = "\(subject) is \(dayText(date)). A card from you would mean a lot."
        if let address = address?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
            text += " \(name)'s address: \(address.replacingOccurrences(of: "\n", with: ", "))"
        }
        return text
    }

    /// The single follow-up.
    static func followUpText(subject: String, date: Date) -> String {
        "A reminder: \(subject) is \(dayText(date)). Still time for a card or a call."
    }

    /// The send button names everyone it will text, so a wrong name is caught before anything goes out
    /// (Graham, Nov 22, 2026): "Text Mom", "Text Mom and Dad", "Text Mom, Dad and Sam", "Text Mom, Dad and 3 others".
    static func sendTitle(_ names: [String]) -> String {
        switch names.count {
        case 0: return "Choose who to text"
        case 1: return "Text \(names[0])"
        case 2: return "Text \(names[0]) and \(names[1])"
        case 3: return "Text \(names[0]), \(names[1]) and \(names[2])"
        default: return "Text \(names[0]), \(names[1]) and \(names.count - 2) others"
        }
    }

    /// The people who can get a text: a number is needed.
    static func textable(_ people: [Recipient]) -> [Recipient] { people.filter { !($0.phone ?? "").isEmpty } }

    struct Recipient: Codable, Equatable, Identifiable, Hashable {
        var id: String
        var name: String
        var phone: String?
    }

    /// What happened for one day.
    struct Record: Codable, Equatable {
        var choice: Choice?
        var dismissed = false
        var followedUp = false
        var handled: Bool { choice != nil || dismissed }
    }
}
