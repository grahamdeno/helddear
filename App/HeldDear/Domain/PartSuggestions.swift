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
        if occasion == .birthday && isPartner(relationship: relationship) {
            return [
                make("Gift", .gift), make("Card", .card), make("Cake", .cake), make("Flowers", .flowers),
                make("Dinner out", .dinner), make("Gift from the kids", .kidsMade),
                make("Breakfast in bed", .theDay, label: "Breakfast in bed"),
            ]
        }
        return [make("Gift", .gift), make("Card", .card), make("Cake", .cake), make("The day", .theDay)]
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
