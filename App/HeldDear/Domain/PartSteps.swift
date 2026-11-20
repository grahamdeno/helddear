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
        case .other: ["open", "idea", "ready"]
        }
    }

    static func readyStep(for family: Family) -> String { steps(for: family).last! }

    static func isReady(step: String, family: Family) -> Bool { step == readyStep(for: family) }

    /// The family for a stored kind. Kinds stored today: gift, card, dinner, call, message, other. A kind this build
    /// doesn't know reads as other, the same way `ActKind` reads it. New kinds join their family in the story that
    /// adds them.
    static func family(forKindRaw raw: String) -> Family {
        switch ActKind(rawValue: raw) ?? .other {
        case .gift: .buy
        case .card: .card
        case .dinner: .day
        case .call, .message: .callOrMessage
        case .other: .other
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
        if let stored = f.storedStep, steps(for: family).contains(stored) { return stored }
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
            // No stored kind maps here yet. When one does: done means its ready step.
            return f.completed ? readyStep(for: family) : "open"
        }
    }
}
