import Foundation

/// How a plan item gets planned (Graham, Nov 22, 2026): first "Do you know what you'll do?" (if not, suggestions),
/// then "how" (make or buy, out or at home), then the follow-up that changes a date (local or online, ship to whom,
/// delivered or picked up, book ahead). The answers set the item's status and its dates, worked back from the day.
/// Plain rules, unit tested; the screens are in Features/Plan/ItemFlowView.swift. Cards keep their own first
/// question (CardChoice); calls and messages have their own flow.
enum ItemFlow {
    enum Path: String, Equatable {
        case make, buy, local, online, toYou, toThem, delivered, pickUp, restaurant, book, walkIn, atHome, outing
    }

    struct Option: Equatable {
        var path: Path
        var title: String
        var caption: String
    }

    struct Question: Equatable {
        var title: String
        var options: [Option]
    }

    /// One date to keep, so many days before the day ("Order by", 10).
    struct Deadline: Equatable {
        var label: String
        var daysBefore: Int
    }

    /// Where the answers end: what to ask for on the last screen, the dates, and the status it moves to.
    struct Finish: Equatable {
        enum Ask: Equatable { case link(String), place, note(String) }
        var ask: Ask
        var deadlines: [Deadline]
        var step: String
    }

    /// Kinds that get this flow.
    static func handles(_ kind: ActKind) -> Bool {
        [.cake, .flowers, .gift, .stocking, .fromSanta, .dinner, .theDay, .kidsMade, .other].contains(kind)
    }

    /// Kinds that start with "Do you know what you'll do?".
    static func asksIfKnown(_ kind: ActKind) -> Bool { handles(kind) && kind != .other }

    static func knowQuestion(kind: ActKind, name: String) -> String {
        switch kind {
        case .cake: "Do you know what cake you'll do for \(name)?"
        case .flowers: "Do you know what flowers you'll get \(name)?"
        case .dinner, .theDay: "Do you know what you'll do for \(name)'s day?"
        case .kidsMade: "Do the kids know what they'll make for \(name)?"
        case .stocking: "Do you know what goes in \(name)'s stocking?"
        default: "Do you know what you'll get \(name)?"
        }
    }

    /// The next question after these answers, or nil when it's time for the last screen.
    static func question(kind: ActKind, path: [Path], name: String, canShipToThem: Bool) -> Question? {
        switch kind {
        case .cake:
            if path.isEmpty {
                return Question(title: "Make it or buy it?", options: [
                    Option(path: .make, title: "Bake it myself", caption: "Save the recipe; a reminder to shop and bake"),
                    Option(path: .buy, title: "Buy it", caption: "From a bakery near you or online"),
                ])
            }
            if path == [.buy] { return localOrOnline(local: "A bakery near you", online: "Order online, shipped") }
            return nil
        case .flowers:
            if path.isEmpty {
                return Question(title: "Delivered or picked up?", options: [
                    Option(path: .delivered, title: "Delivered", caption: "To \(name)'s door on the day"),
                    Option(path: .pickUp, title: "I'll pick them up", caption: "A reminder that morning"),
                ])
            }
            if path == [.delivered] { return localOrOnline(local: "A florist near \(name)", online: "Order online") }
            return nil
        case .gift, .stocking, .fromSanta:
            if path.isEmpty {
                return Question(title: "How are you getting it?", options: [
                    Option(path: .online, title: "Order it online", caption: "Ordered ahead, shipped"),
                    Option(path: .local, title: "Buy it in a store", caption: "A reminder to shop"),
                    Option(path: .make, title: "Make it", caption: "Done a couple of days before"),
                ])
            }
            if path == [.online] && canShipToThem {
                return Question(title: "Ship it to you or to \(name)?", options: [
                    Option(path: .toYou, title: "To me", caption: "So you can wrap it"),
                    Option(path: .toThem, title: "Straight to \(name)", caption: "Ordered a little earlier, arrives at theirs"),
                ])
            }
            return nil
        case .dinner, .theDay:
            if path.isEmpty {
                return Question(title: "Out or at home?", options: [
                    Option(path: .restaurant, title: "A restaurant", caption: "Book a table"),
                    Option(path: .atHome, title: "At home", caption: "Cook something; a reminder to shop"),
                    Option(path: .outing, title: "An outing", caption: "A show, a trip, a day out"),
                ])
            }
            if path == [.restaurant] {
                return Question(title: "Does it need a reservation?", options: [
                    Option(path: .book, title: "Yes, book ahead", caption: "Birthday weekends fill up"),
                    Option(path: .walkIn, title: "No, we'll walk in", caption: "Just the day"),
                ])
            }
            return nil
        case .kidsMade, .other:
            return nil
        default:
            return nil
        }
    }

    private static func localOrOnline(local: String, online: String) -> Question {
        Question(title: "Local or online?", options: [
            Option(path: .local, title: "Local", caption: local),
            Option(path: .online, title: "Online", caption: online),
        ])
    }

    /// The last screen for these answers.
    static func finish(kind: ActKind, path: [Path]) -> Finish {
        switch (kind, path) {
        case (.cake, [.make]):
            return Finish(ask: .link("Recipe link"), deadlines: [Deadline(label: "Shop", daysBefore: 2), Deadline(label: "Bake", daysBefore: 1)], step: "idea")
        case (.cake, [.buy, .local]):
            return Finish(ask: .place, deadlines: [Deadline(label: "Order by", daysBefore: 4), Deadline(label: "Pick up", daysBefore: 1)], step: "idea")
        case (.cake, [.buy, .online]):
            return Finish(ask: .link("The cake's link"), deadlines: [Deadline(label: "Order by", daysBefore: 10), Deadline(label: "Arrives by", daysBefore: 2)], step: "idea")
        case (.flowers, [.delivered, .local]):
            return Finish(ask: .place, deadlines: [Deadline(label: "Order by", daysBefore: 3), Deadline(label: "Delivered", daysBefore: 0)], step: "idea")
        case (.flowers, [.delivered, .online]):
            return Finish(ask: .link("The flowers' link"), deadlines: [Deadline(label: "Order by", daysBefore: 5), Deadline(label: "Delivered", daysBefore: 0)], step: "idea")
        case (.flowers, [.pickUp]):
            return Finish(ask: .place, deadlines: [Deadline(label: "Pick up", daysBefore: 0)], step: "idea")
        case (.gift, [.local]), (.stocking, [.local]), (.fromSanta, [.local]):
            return Finish(ask: .note("What you'll get"), deadlines: [Deadline(label: "Buy by", daysBefore: 3), Deadline(label: "Wrap", daysBefore: 1)], step: "idea")
        case (.gift, [.online, .toThem]), (.stocking, [.online, .toThem]), (.fromSanta, [.online, .toThem]):
            return Finish(ask: .link("The link"), deadlines: [Deadline(label: "Order by", daysBefore: 12), Deadline(label: "Arrives by", daysBefore: 1)], step: "idea")
        case (.gift, [.online]), (.gift, [.online, .toYou]), (.stocking, [.online]), (.stocking, [.online, .toYou]),
             (.fromSanta, [.online]), (.fromSanta, [.online, .toYou]):
            return Finish(ask: .link("The link"), deadlines: [Deadline(label: "Order by", daysBefore: 10), Deadline(label: "Wrap", daysBefore: 1)], step: "idea")
        case (.gift, [.make]), (.stocking, [.make]), (.fromSanta, [.make]):
            return Finish(ask: .note("What you'll make"), deadlines: [Deadline(label: "Finish by", daysBefore: 2), Deadline(label: "Wrap", daysBefore: 1)], step: "idea")
        case (.dinner, [.restaurant, .book]), (.theDay, [.restaurant, .book]):
            return Finish(ask: .place, deadlines: [Deadline(label: "Book by", daysBefore: 14)], step: "idea")
        case (.dinner, [.restaurant, .walkIn]), (.theDay, [.restaurant, .walkIn]):
            return Finish(ask: .place, deadlines: [], step: "idea")
        case (.dinner, [.atHome]), (.theDay, [.atHome]):
            return Finish(ask: .link("Recipe link"), deadlines: [Deadline(label: "Shop", daysBefore: 1)], step: "idea")
        case (.dinner, [.outing]), (.theDay, [.outing]):
            return Finish(ask: .link("Tickets or a link"), deadlines: [Deadline(label: "Book by", daysBefore: 14)], step: "idea")
        case (.kidsMade, _):
            return Finish(ask: .note("What they'll make"), deadlines: [Deadline(label: "Make it", daysBefore: 3)], step: "idea")
        default:
            return Finish(ask: .note("What it is"), deadlines: [Deadline(label: "Done by", daysBefore: 2)], step: "idea")
        }
    }

    /// Each deadline as a date, never before today (a date that's already passed becomes today).
    static func dates(_ finish: Finish, due: Date, now: Date, calendar: Calendar = .current) -> [(label: String, date: Date)] {
        let today = calendar.startOfDay(for: now)
        return finish.deadlines.map { d in
            let date = calendar.date(byAdding: .day, value: -d.daysBefore, to: calendar.startOfDay(for: due)) ?? due
            return (d.label, max(date, today))
        }
    }

    /// "Order by Dec 12 · Pick up Dec 16"
    static func summary(_ dates: [(label: String, date: Date)]) -> String {
        dates.map { "\($0.label) \($0.date.formatted(.dateTime.month(.abbreviated).day()))" }.joined(separator: " · ")
    }
}
