import Foundation

/// Something ordered or bought (Graham, Nov 22, 2026): the item page shows the order itself (where it's from, the
/// order number, when it arrives, tracking), every row editable, and one line of steps with a button for the next.
/// The saved link stays the link: "Found at" before ordering, "Ordered from" after. Plain rules, unit tested.
enum Orders {
    /// Gifts, cakes and flowers, and anything typed in: the things that get ordered or bought.
    static func applies(_ family: PartSteps.Family) -> Bool { [.buy, .orderAhead, .other].contains(family) }

    /// True once it's been ordered or bought: the order number and tracking rows show from then on.
    static func isPlaced(_ step: String) -> Bool { !["open", "idea"].contains(step) }

    /// The link's row name.
    static func fromLabel(step: String) -> String {
        switch step {
        case "open", "idea": "Found at"
        case "bought", "wrapped": "Bought from"
        default: "Ordered from"
        }
    }

    /// The arrival row's name: a target before ordering, the expected day after.
    static func arrivesLabel(step: String) -> String { isPlaced(step) ? "Arrives" : "Needed by" }

    /// The kind's next step after the current one, or nil at the end (or when the current one isn't on the line).
    static func next(after step: String, family: PartSteps.Family) -> String? {
        let line = PartSteps.steps(for: family)
        guard let i = line.firstIndex(of: step), i + 1 < line.count else { return nil }
        return line[i + 1]
    }

    /// The button for moving to a step, in plain words.
    static func buttonTitle(for step: String) -> String {
        switch step {
        case "idea": "I have an idea"
        case "ordered": "I ordered it"
        case "bought": "I bought it"
        case "wrapped": "It's wrapped"
        case "arrived": "It arrived"
        case "ready": "It's ready"
        case "scheduled": "It's scheduled"
        case "booked": "It's booked"
        default: "Mark it \(PartSteps.word(for: step).lowercased())"
        }
    }

    /// A typed or pasted link, with https added when it was left off. Nil for anything that isn't a web address.
    static func link(from text: String) -> URL? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !t.contains(" ") else { return nil }
        let full = t.lowercased().hasPrefix("http://") || t.lowercased().hasPrefix("https://") ? t : "https://" + t
        guard let url = URL(string: full), let host = url.host(), host.contains(".") else { return nil }
        return url
    }

    /// "bakemeawish.com" for "https://www.bakemeawish.com/cakes/123".
    static func shortLink(_ url: URL) -> String {
        let host = url.host() ?? url.absoluteString
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
