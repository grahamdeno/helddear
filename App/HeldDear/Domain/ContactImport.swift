import Contacts
import Foundation

/// Sorting picked contacts (Nov 21): who can be added now, who needs a date, who is already here.
/// Plain values so the rules are unit tested without Contacts.
enum ContactImport {
    struct Pick: Equatable {
        var id: String
        var name: String
        var fullName: String?
        var month: Int?
        var day: Int?
        var year: Int?

        init(id: String, name: String, fullName: String? = nil, month: Int? = nil, day: Int? = nil, year: Int? = nil) {
            self.id = id; self.name = name; self.fullName = fullName; self.month = month; self.day = day; self.year = year
        }

        init(_ contact: CNContact) {
            let given = contact.isKeyAvailable(CNContactGivenNameKey) ? contact.givenName : ""
            let family = contact.isKeyAvailable(CNContactFamilyNameKey) ? contact.familyName : ""
            let nick = contact.isKeyAvailable(CNContactNicknameKey) ? contact.nickname : ""
            let full = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
            var month: Int?, day: Int?, year: Int?
            if contact.isKeyAvailable(CNContactBirthdayKey), let b = contact.birthday,
               let m = b.month, let d = b.day, m != NSDateComponentUndefined, d != NSDateComponentUndefined {
                month = m; day = d
                year = (b.year == nil || b.year == NSDateComponentUndefined) ? nil : b.year
            }
            self.init(id: contact.identifier, name: !nick.isEmpty ? nick : (!given.isEmpty ? given : family),
                      fullName: full.isEmpty ? nil : full, month: month, day: day, year: year)
        }

        var hasBirthday: Bool { month != nil && day != nil }
    }

    struct Outcome: Equatable {
        var ready: [Pick] = []
        var needDate: [Pick] = []
        var already = 0
    }

    static func sort(_ picks: [Pick], known: Set<String>) -> Outcome {
        var out = Outcome()
        var seen = known
        for p in picks {
            if seen.contains(p.id) { out.already += 1; continue }
            seen.insert(p.id)
            if p.hasBirthday && !p.name.isEmpty { out.ready.append(p) }
            else if !p.name.isEmpty { out.needDate.append(p) }
        }
        return out
    }

    /// "Sam added." / "4 added. 1 already in Held Dear." / "Sam is already in Held Dear."
    static func summary(_ o: Outcome) -> String {
        var parts: [String] = []
        if o.ready.count == 1 { parts.append("\(o.ready[0].name) added.") }
        else if o.ready.count > 1 { parts.append("\(o.ready.count) added.") }
        if o.already == 1 { parts.append(parts.isEmpty ? "Already in Held Dear." : "1 already in Held Dear.") }
        else if o.already > 1 { parts.append("\(o.already) already in Held Dear.") }
        return parts.isEmpty ? "Nobody added." : parts.joined(separator: " ")
    }
}
