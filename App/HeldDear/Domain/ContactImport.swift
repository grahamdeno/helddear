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
        /// The card's other dates and the spouse or partner it names, brought in with the person (Nov 22, 2026).
        var dates: [ContactDate] = []
        var partner: String?
        /// The number and mailing address on the card, kept at the moment of picking (Nov 22, 2026). The picker hands
        /// them over even when Held Dear has no Contacts access, and a later lookup needs that access.
        var phone: String?
        var address: MailAddress?

        init(id: String, name: String, fullName: String? = nil, month: Int? = nil, day: Int? = nil, year: Int? = nil,
             dates: [ContactDate] = [], partner: String? = nil, phone: String? = nil, address: MailAddress? = nil) {
            self.id = id; self.name = name; self.fullName = fullName; self.month = month; self.day = day; self.year = year
            self.dates = dates; self.partner = partner; self.phone = phone; self.address = address
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
            let dates: [ContactDate] = contact.isKeyAvailable(CNContactDatesKey) ? contact.dates.compactMap { item in
                let c = item.value as DateComponents
                guard let m = c.month, let d = c.day else { return nil }
                let raw = item.label ?? ""
                return ContactDate(label: raw.isEmpty ? "" : CNLabeledValue<NSDateComponents>.localizedString(forLabel: raw),
                                   isAnniversary: raw == CNLabelDateAnniversary, month: m, day: d,
                                   year: c.year.flatMap { $0 == NSDateComponentUndefined ? nil : $0 })
            } : []
            let partner: String? = contact.isKeyAvailable(CNContactRelationsKey) ? contact.contactRelations.first {
                [CNLabelContactRelationSpouse, CNLabelContactRelationPartner, CNLabelContactRelationWife,
                 CNLabelContactRelationHusband].contains($0.label ?? "")
            }?.value.name : nil
            var phone: String?
            if contact.isKeyAvailable(CNContactPhoneNumbersKey) {
                let mobile = contact.phoneNumbers.first { $0.label == CNLabelPhoneNumberMobile || $0.label == CNLabelPhoneNumberiPhone }
                phone = (mobile ?? contact.phoneNumbers.first)?.value.stringValue
            }
            var address: MailAddress?
            if contact.isKeyAvailable(CNContactPostalAddressesKey), let postal = contact.postalAddresses.first?.value {
                let lines = postal.street.split(separator: "\n").map(String.init)
                address = MailAddress(firstName: given, lastName: family,
                                      address1: lines.first ?? "", address2: lines.dropFirst().joined(separator: " "),
                                      city: postal.city, state: String(postal.state.uppercased().prefix(2)), zip: postal.postalCode)
            }
            self.init(id: contact.identifier, name: !nick.isEmpty ? nick : (!given.isEmpty ? given : family),
                      fullName: full.isEmpty ? nil : full, month: month, day: day, year: year, dates: dates, partner: partner,
                      phone: phone, address: address)
        }

        /// What this pick would fill on a person: only empty fields, so nothing typed in Held Dear is replaced.
        func fills(phone current: String?, address currentAddress: MailAddress?) -> (phone: String?, address: MailAddress?) {
            let p = (current ?? "").isEmpty ? phone.flatMap { $0.isEmpty ? nil : $0 } : nil
            let a = currentAddress == nil ? address.flatMap { $0.address1.isEmpty && $0.city.isEmpty ? nil : $0 } : nil
            return (p, a)
        }

        var hasBirthday: Bool { month != nil && day != nil }
    }

    struct Outcome: Equatable {
        var ready: [Pick] = []
        var needDate: [Pick] = []
        var already = 0
        /// People already here, picked again: their number, address and dates are refreshed from the card (Nov 22, 2026).
        var again: [Pick] = []
        /// How many people gained a number or address from their card.
        var detailsAdded = 0
        /// Other dates brought in from the cards.
        var otherDates = 0
    }

    static func sort(_ picks: [Pick], known: Set<String>) -> Outcome {
        var out = Outcome()
        var seen = known
        for p in picks {
            if seen.contains(p.id) {
                out.already += 1
                if known.contains(p.id), !out.again.contains(where: { $0.id == p.id }) { out.again.append(p) }
                continue
            }
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
        if o.detailsAdded == 1 { parts.append("Brought in a number or address from 1 card.") }
        else if o.detailsAdded > 1 { parts.append("Brought in numbers or addresses from \(o.detailsAdded) cards.") }
        if o.otherDates == 1 { parts.append("Also added 1 other date from their contact cards.") }
        else if o.otherDates > 1 { parts.append("Also added \(o.otherDates) other dates from their contact cards.") }
        return parts.isEmpty ? "Nobody added." : parts.joined(separator: " ")
    }
}
