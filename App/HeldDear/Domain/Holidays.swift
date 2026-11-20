import Foundation

/// Shared holidays (roadmap Epic 1): one event for everyone, planned in one place, each plan saved to its person.
/// Plain rules; views and the alert planner ask here.
enum Holidays {
    /// Holidays offered in 1.0. Valentine's Day is hidden in 1.0 (roadmap 2.6).
    static let offeredIn1_0: [OccasionType] = [.christmas, .mothersDay, .fathersDay]

    /// The ones the user keeps, by default all that 1.0 offers.
    static let defaultsKey = "enabledHolidays"

    static func enabled(_ defaults: UserDefaults = .standard) -> [OccasionType] {
        guard let raw = defaults.array(forKey: defaultsKey) as? [String] else { return offeredIn1_0 }
        let set = Set(raw)
        return offeredIn1_0.filter { set.contains($0.rawValue) }
    }

    static func setEnabled(_ type: OccasionType, _ on: Bool, _ defaults: UserDefaults = .standard) {
        var now = Set(enabled(defaults).map(\.rawValue))
        if on { now.insert(type.rawValue) } else { now.remove(type.rawValue) }
        defaults.set(offeredIn1_0.map(\.rawValue).filter(now.contains), forKey: defaultsKey)
    }

    /// The key that joins every person's moment for one holiday in one year.
    static func groupKey(type: OccasionType, year: Int) -> String? {
        type.kind == .holiday ? "\(type.rawValue)-\(year)" : nil
    }

    /// Lead time for the single holiday heads-up (roadmap 1.4): six weeks.
    static let headsUpDays = 42

    /// "In 35 days, for 5 people", "Tomorrow, for 1 person", "Today, for 3 people".
    static func subline(daysLeft: Int, people: Int) -> String {
        let when: String
        switch daysLeft {
        case ..<1: when = "Today"
        case 1: when = "Tomorrow"
        default: when = "In \(daysLeft) days"
        }
        return "\(when), for \(people) \(people == 1 ? "person" : "people")"
    }

    /// "1 of 5 people ready · 2 of 12 things ready". With nothing planned yet: "Nothing planned yet".
    static func summary(peopleReady: Int, people: Int, thingsReady: Int, things: Int) -> String {
        guard things > 0 else { return "Nothing planned yet" }
        return "\(peopleReady) of \(people) \(people == 1 ? "person" : "people") ready · \(thingsReady) of \(things) \(things == 1 ? "thing" : "things") ready"
    }

    /// The person to plan next: the one with the smallest share ready, ties by name. Nil when everyone is ready.
    static func nextUp(_ people: [(name: String, ready: Int, total: Int)]) -> Int? {
        let open = people.enumerated().filter { $0.element.total == 0 || $0.element.ready < $0.element.total }
        return open.min { a, b in
            let fa = a.element.total == 0 ? 0 : Double(a.element.ready) / Double(a.element.total)
            let fb = b.element.total == 0 ? 0 : Double(b.element.ready) / Double(b.element.total)
            return fa == fb ? a.element.name.localizedCaseInsensitiveCompare(b.element.name) == .orderedAscending : fa < fb
        }?.offset
    }

    /// The heads-up six weeks out: "Christmas is in 6 weeks. 5 people to plan for."
    static func headsUpText(type: OccasionType, people: Int) -> String {
        "\(type.label) is in 6 weeks. \(people) \(people == 1 ? "person" : "people") to plan for."
    }

    /// The morning of: "Merry Christmas. Held Dear has your messages ready for 5 people."
    static func dayOfText(type: OccasionType, people: Int) -> String {
        let opening = type.cardOpening.hasSuffix(",") ? String(type.cardOpening.dropLast()) : type.cardOpening
        return "\(opening). Held Dear has your messages ready for \(people) \(people == 1 ? "person" : "people")."
    }
}

/// How the user is related to a person (roadmap requirement with story 1.6). Stored as plain words on Person.
enum Relationship {
    /// The words offered when asking "Who is Ben to you?", in the order shown.
    static let choices = ["Wife", "Husband", "Partner", "Daughter", "Son", "Mother", "Father", "Grandmother",
                          "Grandfather", "Sister", "Brother", "Aunt", "Uncle", "Cousin", "In-law", "Friend",
                          "Teacher", "Coach", "Neighbor", "Coworker"]

    enum Group: Equatable { case partner, child, parent, sibling, extended, community, unknown }

    /// Who "Who it's from" offers (feedback on build 1010): the household, meaning a partner and the children.
    /// People whose relationship isn't set yet are offered when they're in the inner ring; anyone set as another
    /// relationship (a mother, a brother, a friend) isn't, whatever their ring.
    static func isHouseholdGiver(relationship: String?, isInner: Bool) -> Bool {
        switch group(relationship) {
        case .partner, .child: return true
        case .unknown: return isInner
        default: return false
        }
    }

    static func group(_ relationship: String?) -> Group {
        guard let r = relationship?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !r.isEmpty else {
            return .unknown
        }
        if ["wife", "husband", "spouse", "partner", "girlfriend", "boyfriend", "fiancée", "fiance", "fiancé"].contains(r) { return .partner }
        if ["daughter", "son", "child", "kid", "stepdaughter", "stepson"].contains(r) { return .child }
        if ["mother", "father", "mom", "dad", "parent", "grandmother", "grandfather", "grandma", "grandpa",
            "grandparent", "stepmother", "stepfather"].contains(r) { return .parent }
        if ["sister", "brother", "sibling"].contains(r) || r.hasSuffix("in-law") || r == "in-law" { return .sibling }
        if ["aunt", "uncle", "cousin", "niece", "nephew"].contains(r) { return .extended }
        if ["teacher", "coach", "neighbor", "neighbour", "coworker", "friend", "babysitter", "nanny"].contains(r) { return .community }
        return .unknown
    }
}

/// The free plan limit (roadmap 2.7): plans for 3 people free; Lifetime unlocks plans for everyone. Reminders,
/// the morning-of message and the yearly line stay free for everyone. A person "has a plan" once any of their parts
/// is moved past Not started; adding or suggesting parts is always free.
enum PlanLimit {
    static let freePeople = 3

    /// May the user move a part for `personID` past Not started?
    static func allows(personID: UUID, plannedPeople: Set<UUID>, hasLifetime: Bool) -> Bool {
        hasLifetime || plannedPeople.contains(personID) || plannedPeople.count < freePeople
    }
}

/// Features that talk to Held Dear's server ship built in but switched off in 1.0 (roadmap R2). The switch is set
/// when the app is built, never from the server (R4): add HELDDEAR_SERVER_FEATURES to the Swift compilation
/// conditions to turn them on in a later, reviewed update.
enum AppFeatures {
    #if HELDDEAR_SERVER_FEATURES
    static let serverFeatures = true
    #else
    static let serverFeatures = false
    #endif

    /// The TestFlight-only Lifetime switch (roadmap R3) exists only in builds made with HELDDEAR_TESTFLIGHT_TOOLS,
    /// which testflight.yml sets. It is also gated on Apple's sandbox at run time.
    #if HELDDEAR_TESTFLIGHT_TOOLS
    static let testFlightTools = true
    #else
    static let testFlightTools = false
    #endif
}
