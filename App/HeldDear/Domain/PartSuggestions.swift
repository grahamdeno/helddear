import Foundation

/// What "+ Add something" offers on a plan (roadmap story 2.1). Plain rules, keyed by occasion type and relationship.
enum PartSuggestions {
    struct Suggestion: Equatable {
        /// What the row says.
        let title: String
        /// The kind of part it makes.
        let kind: ActKind
        /// The part's own name when it isn't the kind's ("Breakfast in bed"); nil to use the kind's name.
        let label: String?
    }

    /// Relationship words that mean a spouse or partner.
    static let partnerWords: Set<String> = ["wife", "husband", "spouse", "partner"]

    static func isPartner(relationship: String?) -> Bool {
        guard let r = relationship?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return partnerWords.contains(r)
    }

    private static func make(_ title: String, _ kind: ActKind, label: String? = nil) -> Suggestion {
        Suggestion(title: title, kind: kind, label: label)
    }

    /// A spouse or partner's birthday has the long list; any other occasion or an unknown relationship has the short one.
    static func suggestions(for occasion: OccasionType, relationship: String?) -> [Suggestion] {
        if occasion == .christmas {
            return [make("Gift", .gift), make("Stocking", .stocking), make("From Santa", .fromSanta), make("Card", .card),
                    make("Gift from the kids", .kidsMade), make("The day", .theDay)]
        }
        if occasion.kind == .holiday {
            return [make("Gift", .gift), make("Card", .card), make("Flowers", .flowers),
                    make("Breakfast in bed", .theDay, label: "Breakfast in bed"), make("The day", .theDay)]
        }
        if occasion == .birthday && isPartner(relationship: relationship) {
            return [
                make("Gift", .gift), make("Card", .card), make("Cake", .cake), make("Flowers", .flowers),
                make("Dinner out", .dinner), make("Gift from the kids", .kidsMade),
                make("Breakfast in bed", .theDay, label: "Breakfast in bed"),
            ]
        }
        return [make("Gift", .gift), make("Card", .card), make("Cake", .cake), make("The day", .theDay)]
    }

    /// What a person's plan starts with when they join a shared holiday (roadmap 1.6), by relationship.
    /// Christmas: partner Gift, Stocking, Card, Gift from the kids; child Gift, From Santa, Stocking; parent or
    /// grandparent Gift, Card; sibling or in-law Gift; teacher, coach, neighbor or friend a card; unknown Gift, Card.
    /// Mother's Day and Father's Day: Gift, Card.
    static func holidayStart(for occasion: OccasionType, relationship: String?) -> [Suggestion] {
        guard occasion == .christmas else { return [make("Gift", .gift), make("Card", .card)] }
        switch Relationship.group(relationship) {
        case .partner:
            return [make("Gift", .gift), make("Stocking", .stocking), make("Card", .card), make("Gift from the kids", .kidsMade)]
        case .child:
            return [make("Gift", .gift), make("From Santa", .fromSanta), make("Stocking", .stocking)]
        case .parent:
            return [make("Gift", .gift), make("Card", .card)]
        case .sibling, .extended:
            return [make("Gift", .gift)]
        case .community:
            return [make("Card", .card)]
        case .unknown:
            return [make("Gift", .gift), make("Card", .card)]
        }
    }

    /// True when the plan already has a part like this suggestion ("Added"). A part counts when its kind matches and,
    /// for a suggestion with its own label, the label matches too.
    static func isAdded(_ s: Suggestion, parts: [(kindRaw: String, label: String?)]) -> Bool {
        parts.contains { p in
            guard p.kindRaw == s.kind.rawValue else { return false }
            guard let want = s.label else { return true }
            return p.label?.caseInsensitiveCompare(want) == .orderedSame
        }
    }
}
