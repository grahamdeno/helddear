import Foundation

/// Steps for the parts of a plan (roadmap story 2.3). Each kind of part has its own list, from "open" to its ready
/// step; a part is ready when its step is the last in its list. Plain rules, no storage: `Act.currentStep` asks here.
enum PartSteps {
    /// Kinds of part that share one list of steps.
    enum Family: String, CaseIterable {
        /// Gift, stocking, from Santa.
        case buy
        case card
        /// Made by the kids.
        case make
        /// The day: an outing, a dinner.
        case day
        /// Cake, flowers.
        case orderAhead
        /// Call and message plans.
        case callOrMessage
        /// Something else, typed by the user.
        case other
    }

    static func steps(for family: Family) -> [String] {
        switch family {
        case .buy: ["open", "idea", "bought", "wrapped"]
        case .card: ["open", "idea", "written"]
        case .make: ["open", "idea", "making", "finished"]
        case .day: ["open", "idea", "booked"]
        case .orderAhead: ["open", "idea", "ordered", "ready"]
        case .callOrMessage: ["open", "done"]
        case .other: ["open", "idea", "ordered", "scheduled", "bought", "ready"]
        }
    }

    /// Every status an item can have (feedback on build 1010): each kind shows its own list first (`steps(for:)`),
    /// and any of these is one tap away under "More".
    static let allSteps = ["open", "idea", "ordered", "scheduled", "bought", "making", "arrived", "booked", "written",
                           "wrapped", "finished", "ready"]

    /// Statuses that mean the item is ready for the day.
    static let readySteps: Set<String> = ["wrapped", "written", "booked", "finished", "ready", "done"]

    /// Statuses that carry a date ("Scheduled Oct 1").
    static let datedSteps: Set<String> = ["ordered", "scheduled"]

    /// The kind's own last status, used when an item is completed from elsewhere.
    static func readyStep(for family: Family) -> String { steps(for: family).last! }

    static func isReady(step: String, family: Family) -> Bool { readySteps.contains(step) }

    /// True for any status this item may hold: the full list, plus its kind's own (Done for calls and messages).
    static func isValid(_ step: String, family: Family) -> Bool {
        allSteps.contains(step) || steps(for: family).contains(step)
    }

    /// The statuses under "More" for this kind, in the full list's order.
    static func moreSteps(for family: Family) -> [String] {
        let own = Set(steps(for: family))
        return allSteps.filter { !own.contains($0) }
    }

    /// The family for a stored kind. A kind this build doesn't know reads as other, the same way `ActKind` reads it.
    static func family(forKindRaw raw: String) -> Family {
        switch ActKind(rawValue: raw) ?? .other {
        case .gift: .buy
        case .card: .card
        case .dinner: .day
        case .call, .message: .callOrMessage
        case .other: .other
        case .stocking, .fromSanta: .buy
        case .cake, .flowers: .orderAhead
        case .theDay: .day
        case .kidsMade: .make
        }
    }

    /// What's stored for a part, as plain values.
    struct Facts {
        var role: ActRole
        var kindRaw: String
        /// The step the user picked, if any.
        var storedStep: String?
        var completed = false
        var hasArrivesBy = false
        var hasTitle = false
        var hasWish = false
        var hasDinnerDate = false
    }

    /// Where a part stands. A step the user picked wins when it's in the kind's list; otherwise the step is worked
    /// out from what's stored, so parts saved before steps existed never need rewriting. Nil for greetings.
    static func currentStep(_ f: Facts) -> String? {
        guard f.role == .plan else { return nil }
        let family = family(forKindRaw: f.kindRaw)
        if let stored = f.storedStep, isValid(stored, family: family) { return stored }
        switch family {
        case .buy:
            if f.completed { return "wrapped" }
            if f.hasArrivesBy { return "bought" }
            if f.hasTitle || f.hasWish { return "idea" }
            return "open"
        case .card:
            return f.completed ? "written" : "open"
        case .day:
            return f.hasDinnerDate || f.completed ? "booked" : "open"
        case .callOrMessage:
            return f.completed ? "done" : "open"
        case .other:
            if f.completed { return "ready" }
            if f.hasTitle { return "idea" }
            return "open"
        case .make, .orderAhead:
            // Cake, flowers and kids' gifts: done means the ready step, otherwise nothing is known yet.
            return f.completed ? readyStep(for: family) : "open"
        }
    }
}

// MARK: Words, names and owners (roadmap stories 2.1 to 2.3)

extension PartSteps {
    /// The words for a step, as the "Where it stands" list shows them.
    static func word(for step: String) -> String {
        switch step {
        case "open": "Not started"
        case "idea": "Have an idea"
        case "bought": "Bought"
        case "wrapped": "Wrapped"
        case "written": "Written"
        case "making": "Making it"
        case "finished": "Finished"
        case "booked": "Booked"
        case "ordered": "Ordered"
        case "scheduled": "Scheduled"
        case "arrived": "Arrived"
        case "ready": "Ready"
        case "done": "Done"
        default: "Not started"
        }
    }

    /// The same, as the short pill on a plan row. Only "ordered" is shorter.
    static func pillWord(for step: String) -> String {
        step == "ordered" ? "Ordered" : word(for: step)
    }

    /// How a step pill is drawn: filled for ready, outline for not started, soft fill in between.
    enum Progress: Equatable { case notStarted, started, ready }

    static func progress(step: String, family: Family) -> Progress {
        if isReady(step: step, family: family) { return .ready }
        return step == "open" ? .notStarted : .started
    }

    /// What a kind is called when the part has no label of its own.
    static func defaultName(forKindRaw raw: String) -> String {
        switch ActKind(rawValue: raw) ?? .other {
        case .gift: "Gift"
        case .card: "Card"
        case .call: "Call"
        case .message: "Message"
        case .dinner: "Dinner out"
        case .other: "Something else"
        case .stocking: "Stocking"
        case .fromSanta: "From Santa"
        case .cake: "Cake"
        case .flowers: "Flowers"
        case .theDay: "The day"
        case .kidsMade: "Gift from the kids"
        }
    }

    /// The name shown for a part: its label if it has one; for a gift or something else, the title if it has one;
    /// otherwise the kind's own name. `typed` is true when the words came from the user, so they stay as typed.
    static func displayInfo(kindRaw: String, label: String?, title: String?) -> (text: String, typed: Bool) {
        if let label = label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty { return (label, true) }
        let kind = ActKind(rawValue: kindRaw) ?? .other
        if kind == .gift || kind == .other,
           let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty { return (title, true) }
        return (defaultName(forKindRaw: kindRaw), false)
    }

    static func displayName(kindRaw: String, label: String?, title: String?) -> String {
        displayInfo(kindRaw: kindRaw, label: label, title: title).text
    }
}

/// Who a part is from (story 2.2). Empty means "You". No pronouns.
enum PartOwners {
    /// "You", "From Sam", "From Lily and Rose", "From Lily, Rose and Sam".
    static func text(names: [String]) -> String {
        switch names.count {
        case 0: return "You"
        case 1: return "From \(names[0])"
        case 2: return "From \(names[0]) and \(names[1])"
        default: return "From \(names.dropLast().joined(separator: ", ")) and \(names[names.count - 1])"
        }
    }

    /// Tapping a person adds them, or takes them out when already chosen.
    static func toggled(_ current: [UUID], tapping id: UUID) -> [UUID] {
        current.contains(id) ? current.filter { $0 != id } : current + [id]
    }

    /// Tapping You clears everyone: You is exclusive.
    static func you() -> [UUID] { [] }

    /// Keeps only owners that still exist, in the order of the household list, so a removed person never leaves a
    /// blank behind. If none remain the part reads as You.
    static func existing(_ ids: [UUID], among household: [UUID]) -> [UUID] {
        household.filter { ids.contains($0) }
    }

    /// The row's second line: owner, then " · note" when there's a note.
    /// A gift from the kids names who it's from once that's set: "Gift from Sam", "Gift from Lily and Rose".
    /// Nil when nobody is chosen yet (the row keeps "Gift from the kids").
    static func kidsGiftName(names: [String]) -> String? {
        guard !names.isEmpty else { return nil }
        return "Gift " + text(names: names).replacingOccurrences(of: "From ", with: "from ", options: .anchored)
    }

    static func rowSubtitle(owner: String, note: String?) -> String {
        guard let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else { return owner }
        return "\(owner) · \(note)"
    }

    /// What VoiceOver reads for a row: "Cake, You, Not started".
    static func rowLabel(name: String, owner: String, step: String) -> String {
        "\(name), \(owner), \(PartSteps.word(for: step))"
    }
}

/// How ready a plan is, and the words for it (stories 2.1 and Home).
enum PlanReadiness {
    /// "2 of 6 ready", or "Ready for Anna's birthday" when every part is ready. `subject` is e.g. "Anna's birthday".
    static func summary(ready: Int, total: Int, subject: String) -> String {
        total > 0 && ready == total ? "Ready for \(subject)" : "\(ready) of \(total) ready"
    }

    /// Parts ready, parts in all.
    static func counts(_ steps: [(family: PartSteps.Family, step: String)]) -> (ready: Int, total: Int) {
        (steps.filter { PartSteps.isReady(step: $0.step, family: $0.family) }.count, steps.count)
    }

    /// The Person page's row that opens the plan.
    static func planRowTitle(for type: OccasionType) -> String {
        switch type {
        case .birthday: "Plan the birthday"
        case .anniversary: "Plan the anniversary"
        case .christmas: "Plan Christmas"
        case .valentines: "Plan Valentine's Day"
        case .mothersDay: "Plan Mother's Day"
        case .fathersDay: "Plan Father's Day"
        case .newBaby: "Plan the new baby"
        case .graduation: "Plan the graduation"
        case .newHome: "Plan the new home"
        case .retirement: "Plan the retirement"
        case .event: "Plan the day"
        case .wedding: "Plan the wedding"
        }
    }

    /// "Your wife, turning 40". Unknown pieces are left out; nil when neither is known. No pronouns.
    static func relationLine(relationship: String?, turning: Int?) -> String? {
        let rel = relationship?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().nilIfEmptyString
        switch (rel, turning) {
        case let (r?, t?): return "Your \(r), turning \(t)"
        case let (r?, nil): return "Your \(r)"
        case let (nil, t?): return "Turning \(t)"
        case (nil, nil): return nil
        }
    }

    /// The finished parts for the yearly record: "Pajamas, a card and a cake"; four or more:
    /// "Pajamas, a card, a cake and 2 more". The first word is capitalized; the others are lowercased, except a
    /// name the user typed, which stays as typed. `items` are (text, isTyped) in plan order.
    static func doneList(_ items: [(text: String, typed: Bool)]) -> String {
        func lower(_ i: (text: String, typed: Bool)) -> String {
            guard !i.typed, let f = i.text.first else { return i.text }
            return f.lowercased() + i.text.dropFirst()
        }
        func upper(_ i: (text: String, typed: Bool)) -> String {
            guard let f = i.text.first else { return i.text }
            return f.uppercased() + i.text.dropFirst()
        }
        switch items.count {
        case 0: return ""
        case 1: return upper(items[0])
        case 2: return "\(upper(items[0])) and \(lower(items[1]))"
        case 3: return "\(upper(items[0])), \(lower(items[1])) and \(lower(items[2]))"
        default:
            let rest = items.count - 3
            return "\(upper(items[0])), \(lower(items[1])), \(lower(items[2])) and \(rest) more"
        }
    }

    /// Yearly-record words for a ready part. A gift or something else keeps its typed name; a card is "A card".
    static func doneText(kindRaw: String, label: String?, title: String?) -> (text: String, typed: Bool) {
        let kind = ActKind(rawValue: kindRaw) ?? .other
        if let label = label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty { return (label, true) }
        if kind == .gift || kind == .other,
           let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty { return (title, true) }
        switch kind {
        case .gift: return ("A gift", false)
        case .card: return ("A card", false)
        case .call: return ("A call", false)
        case .message: return ("A message", false)
        case .dinner: return ("Dinner together", false)
        case .other: return ("Something special", false)
        case .stocking: return ("A stocking", false)
        case .fromSanta: return ("A gift from Santa", false)
        case .cake: return ("A cake", false)
        case .flowers: return ("Flowers", false)
        case .theDay: return ("The day", false)
        case .kidsMade: return ("Gift from the kids", false)
        }
    }
}

private extension String {
    var nilIfEmptyString: String? { isEmpty ? nil : self }
}

/// Moments planned on the plan screen (amendment C). Plain rules.
enum PlanMoment {
    /// A plan moment has more than one plan part, or any plan part with a stored step. A single older plan with no
    /// stored step is not one, and behaves exactly as before.
    static func isPlanMoment(planParts: Int, anyStoredStep: Bool) -> Bool { planParts > 1 || anyStoredStep }

    /// The status a plan moment takes after a step changes or a part is added: done when every part is ready,
    /// otherwise planning. Nil means leave the status alone: missed, late, let go and closed never change here.
    static func status(current: MomentStatus, ready: Int, total: Int) -> MomentStatus? {
        switch current {
        case .missed, .lateSent, .letGo, .closed: return nil
        case .upcoming, .planning, .done: return total > 0 && ready == total ? .done : .planning
        }
    }
}
