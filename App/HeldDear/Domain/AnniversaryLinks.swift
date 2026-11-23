import Foundation

/// An anniversary linked to both halves of a couple (approved Nov 22, 2026). One anniversary is kept, on one
/// person's page; the link names the other person, so the day shows on both pages with one date, one count and one
/// alert. Links live in settings (synced like the couple photo), keyed by the anniversary, so no stored-data change
/// is needed. Plain rules, unit tested; views only draw the result.
enum AnniversaryLinks {
    static let key = "anniversaryLinks"

    // MARK: Stored links

    static func partner(of occasionID: UUID?, _ d: UserDefaults = .standard) -> UUID? {
        guard let id = occasionID else { return nil }
        return all(d)[id].flatMap { $0 }
    }

    static func set(_ partnerID: UUID?, for occasionID: UUID, _ d: UserDefaults = .standard) {
        var raw = (d.dictionary(forKey: key) as? [String: String]) ?? [:]
        raw[occasionID.uuidString] = partnerID?.uuidString
        d.set(raw, forKey: key)
    }

    static func all(_ d: UserDefaults = .standard) -> [UUID: UUID] {
        let raw = (d.dictionary(forKey: key) as? [String: String]) ?? [:]
        var out: [UUID: UUID] = [:]
        for (k, v) in raw { if let o = UUID(uuidString: k), let p = UUID(uuidString: v) { out[o] = p } }
        return out
    }

    /// "Don't ask again" for a combine offer, by the pair of anniversaries.
    static let skippedKey = "anniversaryCombineSkipped"

    static func skipKey(_ a: UUID, _ b: UUID) -> String { [a.uuidString, b.uuidString].sorted().joined(separator: "|") }

    static func isSkipped(_ a: UUID, _ b: UUID, _ d: UserDefaults = .standard) -> Bool {
        (d.stringArray(forKey: skippedKey) ?? []).contains(skipKey(a, b))
    }

    static func skip(_ a: UUID, _ b: UUID, _ d: UserDefaults = .standard) {
        var list = d.stringArray(forKey: skippedKey) ?? []
        let k = skipKey(a, b)
        if !list.contains(k) { list.append(k) }
        d.set(list, forKey: skippedKey)
    }

    // MARK: Rules

    /// What the rules need to know about one anniversary.
    struct Day: Equatable {
        let id: UUID
        let ownerID: UUID
        let month: Int
        let day: Int
        let year: Int?
        let partnerName: String?
        /// Parts and steps already planned on it; the one with more is kept when two are combined.
        let planned: Int
    }

    struct Someone: Equatable { let id: UUID; let name: String; let fullName: String }

    /// Anniversaries kept on someone else's page that are linked to this person: shown on this page too.
    static func shared(with personID: UUID, days: [Day], links: [UUID: UUID]) -> [Day] {
        days.filter { $0.ownerID != personID && links[$0.id] == personID }
    }

    /// The name to show for the other half: the linked person's current name, so a rename follows; the typed name
    /// when the linked person is gone or there is no link.
    static func partnerName(typed: String?, linked: Someone?) -> String? {
        if let linked { return linked.name }
        let t = typed?.trimmingCharacters(in: .whitespaces) ?? ""
        return t.isEmpty ? nil : t
    }

    /// Two anniversaries on the same date, kept on two people's pages, that look like the same couple's day: one
    /// names the other person (by link or by name). Each pair once, never one already skipped.
    static func combineOffers(days: [Day], links: [UUID: UUID], people: [Someone], skipped: (UUID, UUID) -> Bool) -> [(keep: Day, drop: Day)] {
        var out: [(Day, Day)] = []
        let sorted = days.sorted { $0.id.uuidString < $1.id.uuidString }
        for (i, a) in sorted.enumerated() {
            for b in sorted.dropFirst(i + 1) where a.ownerID != b.ownerID && a.month == b.month && a.day == b.day {
                guard names(a, b.ownerID, links, people) || names(b, a.ownerID, links, people), !skipped(a.id, b.id) else { continue }
                out.append(keeper(a, b))
            }
        }
        return out
    }

    /// Which of two to keep: the one with more planned, then the one that knows the year, then a steady order.
    static func keeper(_ a: Day, _ b: Day) -> (keep: Day, drop: Day) {
        if a.planned != b.planned { return a.planned > b.planned ? (a, b) : (b, a) }
        if (a.year == nil) != (b.year == nil) { return a.year != nil ? (a, b) : (b, a) }
        return a.id.uuidString < b.id.uuidString ? (a, b) : (b, a)
    }

    private static func names(_ day: Day, _ personID: UUID, _ links: [UUID: UUID], _ people: [Someone]) -> Bool {
        if links[day.id] == personID { return true }
        guard let typed = day.partnerName, !typed.trimmingCharacters(in: .whitespaces).isEmpty,
              let p = people.first(where: { $0.id == personID }) else { return false }
        return NameCleanup.isSamePerson(typed, name: p.name, fullName: p.fullName)
    }

    /// People who can be picked as the other half: everyone but the person, matches for what's typed first, then
    /// partners, then the rest by name.
    static func choices(for ownerID: UUID, typed: String, people: [Someone], partnerIDs: Set<UUID>) -> [Someone] {
        let q = typed.trimmingCharacters(in: .whitespaces).lowercased()
        let others = people.filter { $0.id != ownerID }
        let matching = q.isEmpty ? others : others.filter { $0.name.lowercased().contains(q) || $0.fullName.lowercased().contains(q) }
        return matching.sorted { a, b in
            let pa = partnerIDs.contains(a.id), pb = partnerIDs.contains(b.id)
            if pa != pb { return pa }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
