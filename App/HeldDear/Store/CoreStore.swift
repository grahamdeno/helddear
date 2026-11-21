import Foundation
import CoreData
import Observation

// Epic 3, item 3.0 (approved Nov 21, 2026; model approved by Graham Nov 21, K4): the store moves to Core Data with
// Apple's CloudKit container, so plans can sync to the user's own iCloud (3.1) and a person can be shared (3.2).
//
// The six record types keep every field and every name from version 2. For iCloud: each record keeps its id but the
// id is no longer unique, every field has a default or is optional, and every link between records is optional.
// One field is added: Person.mailingAddress (story 2.13).
//
// The classes below keep the same Swift names and shapes the app used with SwiftData (Person, Occasion, Moment, Wish,
// Act, LedgerEntry), so screens and rules read them the same way. Each class tells SwiftUI when it changes.
// Nothing here talks to iCloud yet: the store opens with no CloudKit container until item 3.1 and Graham's go.

typealias Person = PersonObject
typealias Occasion = OccasionObject
typealias Moment = MomentObject
typealias Wish = WishObject
typealias Act = ActObject
typealias LedgerEntry = LedgerEntryObject

// MARK: - Observation

/// A stored record SwiftUI can watch: every read is noted, every write and every change from elsewhere (a save in
/// another context, iCloud later) tells the views that read it.
class StoredRecord: NSManagedObject, Observable {
    private let registrar = ObservationRegistrar()
    var changeToken: Int { 0 }

    /// Tells views that read this record to redraw.
    func touch() { registrar.withMutation(of: self, keyPath: \StoredRecord.changeToken) {} }

    /// A deleted record that has been saved can't be read; it answers with defaults instead of crashing.
    private var unreadable: Bool { isFault && managedObjectContext == nil && objectID.isTemporaryID == false }

    func read<T>(_ key: String, _ fallback: T) -> T {
        registrar.access(self, keyPath: \StoredRecord.changeToken)
        guard !unreadable else { return fallback }
        return (value(forKey: key) as? T) ?? fallback
    }

    func readOptional<T>(_ key: String) -> T? {
        registrar.access(self, keyPath: \StoredRecord.changeToken)
        guard !unreadable else { return nil }
        return value(forKey: key) as? T
    }

    func write(_ key: String, _ newValue: Any?) {
        // Linked records must be in the same context. SwiftData let a link be made before both were inserted;
        // here the one not yet in a context joins the other's.
        if let other = newValue as? StoredRecord { join(other) }
        if let set = newValue as? NSSet { set.forEach { if let other = $0 as? StoredRecord { join(other) } } }
        registrar.withMutation(of: self, keyPath: \StoredRecord.changeToken) { setValue(newValue, forKey: key) }
    }

    private func join(_ other: StoredRecord) {
        if let mine = managedObjectContext, other.managedObjectContext == nil { mine.insert(other) }
        else if managedObjectContext == nil, let theirs = other.managedObjectContext { theirs.insert(self) }
    }

    /// Lists kept as JSON text (CloudKit-friendly).
    func readList<T: Codable>(_ key: String) -> [T] {
        guard let text: String = readOptional(key), let data = text.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }

    func writeList<T: Codable>(_ key: String, _ list: [T]) {
        let text = (try? JSONEncoder().encode(list)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        write(key, text)
    }

    func readMany<T: StoredRecord>(_ key: String) -> [T] {
        registrar.access(self, keyPath: \StoredRecord.changeToken)
        guard !unreadable, let set = value(forKey: key) as? Set<NSManagedObject> else { return [] }
        return set.compactMap { $0 as? T }.filter { !$0.isDeleted }
    }

    func writeMany<T: StoredRecord>(_ key: String, _ list: [T]) {
        write(key, NSSet(array: list))
    }

    /// Creates a record that isn't in a store yet; `ModelContext.insert` puts it in one.
    convenience init(newOf entityName: String) {
        self.init(entity: CoreStore.model.entitiesByName[entityName]!, insertInto: nil)
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        if primitiveValue(forKey: "id") == nil { setPrimitiveValue(UUID(), forKey: "id") }
    }
}

// MARK: - Records

@objc(PersonObject)
final class PersonObject: StoredRecord {
    var id: UUID { get { read("id", UUID()) } set { write("id", newValue) } }
    var name: String { get { read("name", "") } set { write("name", newValue) } }
    var fullName: String { get { read("fullName", "") } set { write("fullName", newValue) } }
    var contactID: String? { get { readOptional("contactID") } set { write("contactID", newValue) } }
    var manualPhone: String? { get { readOptional("manualPhone") } set { write("manualPhone", newValue) } }
    var ringRaw: String { get { read("ringRaw", Ring.outer.rawValue) } set { write("ringRaw", newValue) } }
    var photoFiles: [String] { get { readList("photoFiles") } set { writeList("photoFiles", newValue) } }
    var createdAt: Date { get { read("createdAt", Date.distantPast) } set { write("createdAt", newValue) } }
    var showAgeOnCard: Bool { get { read("showAgeOnCard", false) } set { write("showAgeOnCard", newValue) } }
    var loves: [String] { get { readList("loves") } set { writeList("loves", newValue) } }
    var sizes: String? { get { readOptional("sizes") } set { write("sizes", newValue) } }
    var goodToKnow: String? { get { readOptional("goodToKnow") } set { write("goodToKnow", newValue) } }
    var relationship: String? { get { readOptional("relationship") } set { write("relationship", newValue) } }
    /// Story 2.13: an address typed for someone whose contact card has none. Contacts are never written.
    var mailingAddress: MailAddress? {
        get {
            guard let text: String = readOptional("mailingAddress"), let data = text.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(MailAddress.self, from: data)
        }
        set { write("mailingAddress", newValue.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }) }
    }

    var wishes: [Wish] { get { readMany("wishes") } set { writeMany("wishes", newValue) } }
    var occasions: [Occasion] { get { readMany("occasions") } set { writeMany("occasions", newValue) } }
    var ledger: [LedgerEntry] { get { readMany("ledger") } set { writeMany("ledger", newValue) } }

    convenience init(name: String, fullName: String? = nil, contactID: String? = nil, ring: Ring = .outer) {
        self.init(newOf: "Person")
        setPrimitiveValue(UUID(), forKey: "id")
        self.name = name
        self.fullName = fullName ?? name
        self.contactID = contactID
        self.ringRaw = ring.rawValue
        self.photoFiles = []
        self.loves = []
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

    var birthday: Occasion? { occasions.sorted { $0.id.uuidString < $1.id.uuidString }.first { $0.type == .birthday } }
    var openWishes: [Wish] { wishes.filter { $0.status == .open }.sorted { $0.capturedAt > $1.capturedAt } }
    var sortedLedger: [LedgerEntry] { ledger.sorted { $0.year == $1.year ? $0.createdAt > $1.createdAt : $0.year > $1.year } }
}

@objc(OccasionObject)
final class OccasionObject: StoredRecord {
    var id: UUID { get { read("id", UUID()) } set { write("id", newValue) } }
    var typeRaw: String { get { read("typeRaw", OccasionType.birthday.rawValue) } set { write("typeRaw", newValue) } }
    var month: Int { get { read("month", 1) } set { write("month", newValue) } }
    var day: Int { get { read("day", 1) } set { write("day", newValue) } }
    var birthYear: Int? { get { readOptional("birthYear") } set { write("birthYear", newValue) } }
    var ringOverrideRaw: String? { get { readOptional("ringOverrideRaw") } set { write("ringOverrideRaw", newValue) } }
    var extraRecipientIDs: [UUID] { get { readList("extraRecipientIDs") } set { writeList("extraRecipientIDs", newValue) } }
    var partnerName: String? { get { readOptional("partnerName") } set { write("partnerName", newValue) } }
    var person: Person? { get { readOptional("person") } set { write("person", newValue) } }
    var moments: [Moment] { get { readMany("moments") } set { writeMany("moments", newValue) } }

    convenience init(type: OccasionType = .birthday, month: Int, day: Int, birthYear: Int? = nil) {
        self.init(newOf: "Occasion")
        setPrimitiveValue(UUID(), forKey: "id")
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

@objc(MomentObject)
final class MomentObject: StoredRecord {
    var id: UUID { get { read("id", UUID()) } set { write("id", newValue) } }
    var year: Int { get { read("year", 2026) } set { write("year", newValue) } }
    var dueDate: Date { get { read("dueDate", Date.distantPast) } set { write("dueDate", newValue) } }
    var statusRaw: String { get { read("statusRaw", MomentStatus.upcoming.rawValue) } set { write("statusRaw", newValue) } }
    var headsUpAt: Date? { get { readOptional("headsUpAt") } set { write("headsUpAt", newValue) } }
    var callStartedAt: Date? { get { readOptional("callStartedAt") } set { write("callStartedAt", newValue) } }
    var photoPromptShown: Bool { get { read("photoPromptShown", false) } set { write("photoPromptShown", newValue) } }
    var missedAt: Date? { get { readOptional("missedAt") } set { write("missedAt", newValue) } }
    var familyPageID: String? { get { readOptional("familyPageID") } set { write("familyPageID", newValue) } }
    var familyOwnerKey: String? { get { readOptional("familyOwnerKey") } set { write("familyOwnerKey", newValue) } }
    var familyInviteURL: String? { get { readOptional("familyInviteURL") } set { write("familyInviteURL", newValue) } }
    var familyGiftURL: String? { get { readOptional("familyGiftURL") } set { write("familyGiftURL", newValue) } }
    var occasion: Occasion? { get { readOptional("occasion") } set { write("occasion", newValue) } }
    var acts: [Act] { get { readMany("acts") } set { writeMany("acts", newValue) } }

    convenience init(year: Int, dueDate: Date) {
        self.init(newOf: "Moment")
        setPrimitiveValue(UUID(), forKey: "id")
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
    var greetingSent: Bool {
        if greeting?.isDone == true { return true }
        if let plan, plan.isDone, plan.kind == .call || plan.kind == .message { return true }
        return false
    }

    var turning: Int? {
        OccasionRules.count(type: occasion?.type ?? .birthday, startYear: occasion?.birthYear, occurrenceYear: year)
    }
    var type: OccasionType { occasion?.type ?? .birthday }
    var subject: String { type.subject(name: person?.name ?? "", partner: occasion?.partnerName) }
    var countLine: String? { type.countLine(turning) }
    var occasionLine: String {
        var line = countLine ?? type.title(partner: occasion?.partnerName)
        if type == .anniversary, let partner = occasion?.partnerName { line += " with \(partner)" }
        return line
    }
}

@objc(WishObject)
final class WishObject: StoredRecord {
    var id: UUID { get { read("id", UUID()) } set { write("id", newValue) } }
    var text: String { get { read("text", "") } set { write("text", newValue) } }
    var url: String? { get { readOptional("url") } set { write("url", newValue) } }
    var imageFile: String? { get { readOptional("imageFile") } set { write("imageFile", newValue) } }
    var capturedAt: Date { get { read("capturedAt", Date.distantPast) } set { write("capturedAt", newValue) } }
    var statusRaw: String { get { read("statusRaw", WishStatus.open.rawValue) } set { write("statusRaw", newValue) } }
    var person: Person? { get { readOptional("person") } set { write("person", newValue) } }

    convenience init(text: String, url: String? = nil, imageFile: String? = nil, capturedAt: Date = Date()) {
        self.init(newOf: "Wish")
        setPrimitiveValue(UUID(), forKey: "id")
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

    var savedLine: String {
        let month = capturedAt.formatted(.dateTime.month(.wide))
        return url != nil ? "Saved from a link in \(month)" : "Saved in \(month)"
    }

    var host: String? { url.flatMap { URL(string: $0)?.host() }.map { $0.replacingOccurrences(of: "www.", with: "") } }
}

@objc(ActObject)
final class ActObject: StoredRecord {
    var id: UUID { get { read("id", UUID()) } set { write("id", newValue) } }
    var roleRaw: String { get { read("roleRaw", ActRole.plan.rawValue) } set { write("roleRaw", newValue) } }
    var kindRaw: String { get { read("kindRaw", ActKind.other.rawValue) } set { write("kindRaw", newValue) } }
    var title: String? { get { readOptional("title") } set { write("title", newValue) } }
    var wishID: UUID? { get { readOptional("wishID") } set { write("wishID", newValue) } }
    var fromNote: String? { get { readOptional("fromNote") } set { write("fromNote", newValue) } }
    var dinnerDate: Date? { get { readOptional("dinnerDate") } set { write("dinnerDate", newValue) } }
    var arrivesBy: Date? { get { readOptional("arrivesBy") } set { write("arrivesBy", newValue) } }
    var photoFile: String? { get { readOptional("photoFile") } set { write("photoFile", newValue) } }
    var cardFile: String? { get { readOptional("cardFile") } set { write("cardFile", newValue) } }
    var completedAt: Date? { get { readOptional("completedAt") } set { write("completedAt", newValue) } }
    var confirmedRaw: String? { get { readOptional("confirmedRaw") } set { write("confirmedRaw", newValue) } }
    var createdAt: Date { get { read("createdAt", Date.distantPast) } set { write("createdAt", newValue) } }
    var moment: Moment? { get { readOptional("moment") } set { write("moment", newValue) } }
    var label: String? { get { readOptional("label") } set { write("label", newValue) } }
    var step: String? { get { readOptional("step") } set { write("step", newValue) } }
    var ownerIDs: [UUID] { get { readList("ownerIDs") } set { writeList("ownerIDs", newValue) } }
    var note: String? { get { readOptional("note") } set { write("note", newValue) } }
    var sortOrder: Int { get { read("sortOrder", 0) } set { write("sortOrder", newValue) } }

    convenience init(role: ActRole, kind: ActKind, title: String? = nil, wishID: UUID? = nil) {
        self.init(newOf: "Act")
        setPrimitiveValue(UUID(), forKey: "id")
        self.roleRaw = role.rawValue
        self.kindRaw = kind.rawValue
        self.title = title
        self.wishID = wishID
        self.ownerIDs = []
        self.createdAt = Date()
    }

    var role: ActRole { ActRole(rawValue: roleRaw) ?? .plan }
    var kind: ActKind { ActKind(rawValue: kindRaw) ?? .other }
    var isDone: Bool { completedAt != nil }

    var currentStep: String? {
        PartSteps.currentStep(PartSteps.Facts(
            role: role, kindRaw: kindRaw, storedStep: step, completed: completedAt != nil,
            hasArrivesBy: arrivesBy != nil, hasTitle: title != nil, hasWish: wishID != nil,
            hasDinnerDate: dinnerDate != nil))
    }

    var isReady: Bool {
        guard let currentStep else { return false }
        return PartSteps.isReady(step: currentStep, family: PartSteps.family(forKindRaw: kindRaw))
    }

    func complete(_ how: ConfirmedBy, at date: Date = Date()) {
        completedAt = date
        confirmedRaw = how.rawValue
    }
}

@objc(LedgerEntryObject)
final class LedgerEntryObject: StoredRecord {
    var id: UUID { get { read("id", UUID()) } set { write("id", newValue) } }
    var year: Int { get { read("year", 2026) } set { write("year", newValue) } }
    var occasionTypeRaw: String { get { read("occasionTypeRaw", OccasionType.birthday.rawValue) } set { write("occasionTypeRaw", newValue) } }
    var what: String { get { read("what", "") } set { write("what", newValue) } }
    var photoFile: String? { get { readOptional("photoFile") } set { write("photoFile", newValue) } }
    var cardFile: String? { get { readOptional("cardFile") } set { write("cardFile", newValue) } }
    var line: String? { get { readOptional("line") } set { write("line", newValue) } }
    var momentID: UUID? { get { readOptional("momentID") } set { write("momentID", newValue) } }
    var personName: String { get { read("personName", "") } set { write("personName", newValue) } }
    var createdAt: Date { get { read("createdAt", Date.distantPast) } set { write("createdAt", newValue) } }
    var person: Person? { get { readOptional("person") } set { write("person", newValue) } }

    convenience init(year: Int, type: OccasionType, what: String, photoFile: String?, line: String?, personName: String, momentID: UUID?) {
        self.init(newOf: "LedgerEntry")
        setPrimitiveValue(UUID(), forKey: "id")
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

extension PersonObject: Identifiable {}
extension OccasionObject: Identifiable {}
extension MomentObject: Identifiable {}
extension WishObject: Identifiable {}
extension ActObject: Identifiable {}
extension LedgerEntryObject: Identifiable {}

// MARK: - The model

enum CoreStore {
    /// Store version 3 (the first Core Data version).
    static let version = "3.0.0"

    /// One model for every container, so records made before they're inserted belong to it.
    static let model: NSManagedObjectModel = makeModel()

    private static func attr(_ name: String, _ type: NSAttributeType, default value: Any? = nil) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = true
        a.defaultValue = value
        return a
    }

    private static func entity(_ name: String, _ cls: AnyClass, _ attrs: [NSAttributeDescription]) -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = name
        e.managedObjectClassName = NSStringFromClass(cls)
        e.properties = attrs
        return e
    }

    private static func link(_ from: NSEntityDescription, _ name: String, to: NSEntityDescription, many: Bool,
                             rule: NSDeleteRule, inverse: NSRelationshipDescription? = nil) -> NSRelationshipDescription {
        let r = NSRelationshipDescription()
        r.name = name
        r.destinationEntity = to
        r.isOptional = true
        r.minCount = 0
        r.maxCount = many ? 0 : 1
        r.deleteRule = rule
        from.properties.append(r)
        if let inverse { r.inverseRelationship = inverse; inverse.inverseRelationship = r }
        return r
    }

    private static func makeModel() -> NSManagedObjectModel {
        let s = NSAttributeType.stringAttributeType, d = NSAttributeType.dateAttributeType
        let u = NSAttributeType.UUIDAttributeType, i = NSAttributeType.integer64AttributeType
        let b = NSAttributeType.booleanAttributeType

        let person = entity("Person", PersonObject.self, [
            attr("id", u), attr("name", s, default: ""), attr("fullName", s, default: ""), attr("contactID", s),
            attr("manualPhone", s), attr("ringRaw", s, default: Ring.outer.rawValue), attr("photoFiles", s, default: "[]"),
            attr("createdAt", d, default: Date(timeIntervalSince1970: 0)), attr("showAgeOnCard", b, default: false),
            attr("loves", s, default: "[]"), attr("sizes", s), attr("goodToKnow", s), attr("relationship", s),
            attr("mailingAddress", s)])
        let occasion = entity("Occasion", OccasionObject.self, [
            attr("id", u), attr("typeRaw", s, default: OccasionType.birthday.rawValue), attr("month", i, default: 1),
            attr("day", i, default: 1), attr("birthYear", i), attr("ringOverrideRaw", s),
            attr("extraRecipientIDs", s, default: "[]"), attr("partnerName", s)])
        let moment = entity("Moment", MomentObject.self, [
            attr("id", u), attr("year", i, default: 2026), attr("dueDate", d, default: Date(timeIntervalSince1970: 0)),
            attr("statusRaw", s, default: MomentStatus.upcoming.rawValue), attr("headsUpAt", d), attr("callStartedAt", d),
            attr("photoPromptShown", b, default: false), attr("missedAt", d), attr("familyPageID", s),
            attr("familyOwnerKey", s), attr("familyInviteURL", s), attr("familyGiftURL", s)])
        let wish = entity("Wish", WishObject.self, [
            attr("id", u), attr("text", s, default: ""), attr("url", s), attr("imageFile", s),
            attr("capturedAt", d, default: Date(timeIntervalSince1970: 0)), attr("statusRaw", s, default: WishStatus.open.rawValue)])
        let act = entity("Act", ActObject.self, [
            attr("id", u), attr("roleRaw", s, default: ActRole.plan.rawValue), attr("kindRaw", s, default: ActKind.other.rawValue),
            attr("title", s), attr("wishID", u), attr("fromNote", s), attr("dinnerDate", d), attr("arrivesBy", d),
            attr("photoFile", s), attr("cardFile", s), attr("completedAt", d), attr("confirmedRaw", s),
            attr("createdAt", d, default: Date(timeIntervalSince1970: 0)), attr("label", s), attr("step", s),
            attr("ownerIDs", s, default: "[]"), attr("note", s), attr("sortOrder", i, default: 0)])
        let ledger = entity("LedgerEntry", LedgerEntryObject.self, [
            attr("id", u), attr("year", i, default: 2026), attr("occasionTypeRaw", s, default: OccasionType.birthday.rawValue),
            attr("what", s, default: ""), attr("photoFile", s), attr("cardFile", s), attr("line", s), attr("momentID", u),
            attr("personName", s, default: ""), attr("createdAt", d, default: Date(timeIntervalSince1970: 0))])

        // Links: the same delete rules as version 2. Every link is optional, as iCloud requires.
        let wishPerson = link(wish, "person", to: person, many: false, rule: .nullifyDeleteRule)
        _ = link(person, "wishes", to: wish, many: true, rule: .cascadeDeleteRule, inverse: wishPerson)
        let occasionPerson = link(occasion, "person", to: person, many: false, rule: .nullifyDeleteRule)
        _ = link(person, "occasions", to: occasion, many: true, rule: .cascadeDeleteRule, inverse: occasionPerson)
        let ledgerPerson = link(ledger, "person", to: person, many: false, rule: .nullifyDeleteRule)
        _ = link(person, "ledger", to: ledger, many: true, rule: .nullifyDeleteRule, inverse: ledgerPerson)
        let momentOccasion = link(moment, "occasion", to: occasion, many: false, rule: .nullifyDeleteRule)
        _ = link(occasion, "moments", to: moment, many: true, rule: .cascadeDeleteRule, inverse: momentOccasion)
        let actMoment = link(act, "moment", to: moment, many: false, rule: .nullifyDeleteRule)
        _ = link(moment, "acts", to: act, many: true, rule: .cascadeDeleteRule, inverse: actMoment)

        let m = NSManagedObjectModel()
        m.entities = [person, occasion, moment, wish, act, ledger]
        return m
    }
}

// MARK: - The SwiftData-shaped front the app already uses

/// An order for fetched records, by one field. Compares in Swift, so any field works.
struct SortDescriptor<T> {
    let areInIncreasingOrder: (T, T) -> Bool
    init<V: Comparable>(_ keyPath: KeyPath<T, V>, order: SortOrder = .forward) {
        areInIncreasingOrder = { a, b in order == .forward ? a[keyPath: keyPath] < b[keyPath: keyPath] : a[keyPath: keyPath] > b[keyPath: keyPath] }
    }
}

/// What a fetch asks for: a record type and, optionally, an order. Sorting happens in memory; the store is small.
struct FetchDescriptor<T: StoredRecord> {
    var sortBy: [SortDescriptor<T>] = []
    init(sortBy: [SortDescriptor<T>] = []) { self.sortBy = sortBy }
}

/// The opened Core Data store.
final class ModelContainer {
    let persistent: NSPersistentCloudKitContainer
    let mainContext: ModelContext
    init(persistent: NSPersistentCloudKitContainer) {
        self.persistent = persistent
        self.mainContext = ModelContext(persistent.viewContext)
    }
}

/// A place to read and change records, shaped like SwiftData's so the app's code reads the same.
final class ModelContext {
    let moc: NSManagedObjectContext
    private var observer: NSObjectProtocol?

    init(_ moc: NSManagedObjectContext) {
        self.moc = moc
        moc.automaticallyMergesChangesFromParent = true
        moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        // A change made elsewhere (another context now, iCloud later) redraws the screens that read it.
        observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: moc,
                                                          queue: nil) { note in
            for key in [NSUpdatedObjectsKey, NSRefreshedObjectsKey] {
                (note.userInfo?[key] as? Set<NSManagedObject>)?.forEach { ($0 as? StoredRecord)?.touch() }
            }
        }
    }

    /// A second context on the same store, for tests that reopen.
    convenience init(_ container: ModelContainer) {
        self.init(container.persistent.newBackgroundContextOnMain())
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    var hasChanges: Bool { moc.hasChanges }

    func insert(_ record: StoredRecord) {
        if record.managedObjectContext == nil { moc.insert(record) }
    }

    func delete(_ record: StoredRecord) {
        guard record.managedObjectContext === moc else { return }
        moc.delete(record)
    }

    func save() throws {
        if moc.hasChanges { try moc.save() }
    }

    func fetch<T: StoredRecord>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        let request = NSFetchRequest<NSManagedObject>(entityName: T.entityName)
        let found = try moc.fetch(request).compactMap { $0 as? T }
        return found.sorted { a, b in
            for d in descriptor.sortBy {
                if d.areInIncreasingOrder(a, b) { return true }
                if d.areInIncreasingOrder(b, a) { return false }
            }
            return false
        }
    }

    func fetchCount<T: StoredRecord>(_ descriptor: FetchDescriptor<T>) throws -> Int {
        try moc.count(for: NSFetchRequest<NSManagedObject>(entityName: T.entityName))
    }
}

extension StoredRecord {
    class var entityName: String {
        switch self {
        case is PersonObject.Type: return "Person"
        case is OccasionObject.Type: return "Occasion"
        case is MomentObject.Type: return "Moment"
        case is WishObject.Type: return "Wish"
        case is ActObject.Type: return "Act"
        default: return "LedgerEntry"
        }
    }
}

extension NSPersistentContainer {
    /// A main-queue context on the same store, separate from the view context.
    func newBackgroundContextOnMain() -> NSManagedObjectContext {
        let c = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        c.persistentStoreCoordinator = persistentStoreCoordinator
        return c
    }
}
