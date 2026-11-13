import Foundation
import SwiftData

// The data model from the plan doc. Moment is the unit of work: one occasion, in one year.
// Wishes and ledger entries attach to the Person, never to an occasion.
// Address and phone are read live from Contacts and never copied.

@Model
final class Person {
    @Attribute(.unique) var id: UUID
    /// The name as the user knows them ("Mom"). Shown everywhere.
    var name: String
    /// Full contact name, used to match typed names and to tell two Mikes apart.
    var fullName: String
    /// CNContact identifier. Stored apart from the record id because contact ids differ between devices.
    var contactID: String?
    /// For people not linked to a contact: a number the user typed on the Person screen.
    var manualPhone: String?
    var ringRaw: String
    /// The app's own ordered photo set for this person (file names in PhotoStore).
    var photoFiles: [String]
    var createdAt: Date
    /// Many adults don't want their age on a card; off unless turned on for this person.
    var showAgeOnCard: Bool = false
    /// The portrait (v2): things they love, in the user's words ("gardening", "dark chocolate").
    var loves: [String] = []
    /// Sizes in one line, in the user's words ("M tops, 8.5 shoes").
    var sizes: String?
    /// Anything else worth keeping ("Allergic to lilies", "Calls on Sundays").
    var goodToKnow: String?

    @Relationship(deleteRule: .cascade, inverse: \Wish.person) var wishes: [Wish] = []
    @Relationship(deleteRule: .cascade, inverse: \Occasion.person) var occasions: [Occasion] = []
    @Relationship(deleteRule: .nullify, inverse: \LedgerEntry.person) var ledger: [LedgerEntry] = []

    init(name: String, fullName: String? = nil, contactID: String? = nil, ring: Ring = .outer) {
        self.id = UUID()
        self.name = name
        self.fullName = fullName ?? name
        self.contactID = contactID
        self.ringRaw = ring.rawValue
        self.photoFiles = []
        self.createdAt = Date()
    }

    var ring: Ring {
        get { Ring(rawValue: ringRaw) ?? .outer }
        set { ringRaw = newValue.rawValue }
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var birthday: Occasion? { occasions.first { $0.type == .birthday } }
    var openWishes: [Wish] { wishes.filter { $0.status == .open }.sorted { $0.capturedAt > $1.capturedAt } }
    var sortedLedger: [LedgerEntry] { ledger.sorted { $0.year == $1.year ? $0.createdAt > $1.createdAt : $0.year > $1.year } }
}

@Model
final class Occasion {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var month: Int
    var day: Int
    /// Optional; used only for milestones like "turning 70".
    var birthYear: Int?
    /// Per-occasion ring override (stage 4). The user only ever sets the person's default in v1.
    var ringOverrideRaw: String?
    /// Further recipients for a pair occasion (stage 2 anniversaries). Empty for birthdays.
    var extraRecipientIDs: [UUID]
    /// The other half of a couple for an anniversary ("Dad" in "Mom & Dad's anniversary"), in the user's words.
    var partnerName: String?
    var person: Person?
    @Relationship(deleteRule: .cascade, inverse: \Moment.occasion) var moments: [Moment] = []

    init(type: OccasionType = .birthday, month: Int, day: Int, birthYear: Int? = nil) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.month = month
        self.day = day
        self.birthYear = birthYear
        self.extraRecipientIDs = []
    }

    var type: OccasionType { OccasionType(rawValue: typeRaw) ?? .birthday }

    var effectiveRing: Ring {
        if let raw = ringOverrideRaw, let r = Ring(rawValue: raw) { return r }
        return person?.ring ?? .outer
    }
}

@Model
final class Moment {
    @Attribute(.unique) var id: UUID
    var year: Int
    var dueDate: Date
    var statusRaw: String
    var headsUpAt: Date?
    /// Set when the app starts a call, so a connected outgoing call right after counts as done.
    var callStartedAt: Date?
    var photoPromptShown: Bool
    var missedAt: Date?
    /// Family page for this day (FamilyPages). The owner key never leaves this iPhone except to manage the page.
    var familyPageID: String?
    var familyOwnerKey: String?
    var familyInviteURL: String?
    var familyGiftURL: String?
    var occasion: Occasion?
    @Relationship(deleteRule: .cascade, inverse: \Act.moment) var acts: [Act] = []

    init(year: Int, dueDate: Date) {
        self.id = UUID()
        self.year = year
        self.dueDate = dueDate
        self.statusRaw = MomentStatus.upcoming.rawValue
        self.photoPromptShown = false
    }

    var status: MomentStatus {
        get { MomentStatus(rawValue: statusRaw) ?? .upcoming }
        set { statusRaw = newValue.rawValue }
    }

    var person: Person? { occasion?.person }
    var plan: Act? { acts.filter { $0.role == .plan }.sorted { $0.createdAt > $1.createdAt }.first }
    var greeting: Act? { acts.filter { $0.role == .greeting }.sorted { $0.createdAt > $1.createdAt }.first }
    var anyActDone: Bool { acts.contains { $0.completedAt != nil } }
    /// The day-of message or call happened (as a greeting, or as the plan itself).
    var greetingSent: Bool {
        if greeting?.isDone == true { return true }
        if let plan, plan.isDone, plan.kind == .call || plan.kind == .message { return true }
        return false
    }

    var turning: Int? {
        OccasionRules.count(type: occasion?.type ?? .birthday, startYear: occasion?.birthYear, occurrenceYear: year)
    }
    var type: OccasionType { occasion?.type ?? .birthday }
    /// "Mom's birthday", "Mom & Dad's anniversary", "Christmas for Mom".
    var subject: String { type.subject(name: person?.name ?? "", partner: occasion?.partnerName) }
    /// "Turns 68", "40th anniversary", or nil.
    var countLine: String? { type.countLine(turning) }
    /// "Turns 68", "Birthday", "40th anniversary with Dad", "Christmas".
    var occasionLine: String {
        var line = countLine ?? type.label
        if type == .anniversary, let partner = occasion?.partnerName { line += " with \(partner)" }
        return line
    }
}

@Model
final class Wish {
    @Attribute(.unique) var id: UUID
    var text: String
    var url: String?
    var imageFile: String?
    var capturedAt: Date
    var statusRaw: String
    var person: Person?

    init(text: String, url: String? = nil, imageFile: String? = nil, capturedAt: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.url = url
        self.imageFile = imageFile
        self.capturedAt = capturedAt
        self.statusRaw = WishStatus.open.rawValue
    }

    var status: WishStatus {
        get { WishStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    /// "She mentioned them in July" without a pronoun: "Saved in July".
    var savedLine: String {
        let month = capturedAt.formatted(.dateTime.month(.wide))
        return url != nil ? "Saved from a link in \(month)" : "Saved in \(month)"
    }

    var host: String? { url.flatMap { URL(string: $0)?.host() }.map { $0.replacingOccurrences(of: "www.", with: "") } }
}

@Model
final class Act {
    @Attribute(.unique) var id: UUID
    var roleRaw: String
    var kindRaw: String
    /// What it is in words: the wish text, "Something else" description, or nil for card/call/dinner.
    var title: String?
    var wishID: UUID?
    /// "from both of us". Stage 4 links these names to household members.
    var fromNote: String?
    var dinnerDate: Date?
    var photoFile: String?
    /// The rendered card image that was sent, for the yearly record and the look-back.
    var cardFile: String?
    var completedAt: Date?
    var confirmedRaw: String?
    var createdAt: Date
    var moment: Moment?

    init(role: ActRole, kind: ActKind, title: String? = nil, wishID: UUID? = nil) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.kindRaw = kind.rawValue
        self.title = title
        self.wishID = wishID
        self.createdAt = Date()
    }

    var role: ActRole { ActRole(rawValue: roleRaw) ?? .plan }
    var kind: ActKind { ActKind(rawValue: kindRaw) ?? .other }
    var isDone: Bool { completedAt != nil }

    func complete(_ how: ConfirmedBy, at date: Date = Date()) {
        completedAt = date
        confirmedRaw = how.rawValue
    }
}

@Model
final class LedgerEntry {
    @Attribute(.unique) var id: UUID
    var year: Int
    var occasionTypeRaw: String
    var what: String
    var photoFile: String?
    var cardFile: String?
    var line: String?
    var momentID: UUID?
    /// Copied in so the entry still reads right if the occasion is deleted.
    var personName: String
    var createdAt: Date
    var person: Person?

    init(year: Int, type: OccasionType, what: String, photoFile: String?, line: String?, personName: String, momentID: UUID?) {
        self.id = UUID()
        self.year = year
        self.occasionTypeRaw = type.rawValue
        self.what = what
        self.photoFile = photoFile
        self.line = line
        self.personName = personName
        self.momentID = momentID
        self.createdAt = Date()
    }
}

enum Store {
    static let schema = Schema([Person.self, Occasion.self, Moment.self, Wish.self, Act.self, LedgerEntry.self])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Held Dear could not open its database: \(error)")
        }
    }
}
