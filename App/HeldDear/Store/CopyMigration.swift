import Foundation
import CoreData
import SwiftData

/// Copies a version 2 store (SwiftData) into the version 3 store (Core Data), once (Epic 3, item 3.0). Every record
/// and every field is copied, links are rebuilt by id, and every count is checked before the copy is kept. The old
/// store is only read. An address kept in settings for a person (story 2.13) moves onto that person.
enum CopyMigration {
    struct Report: Equatable {
        var people = 0, occasions = 0, moments = 0, acts = 0, wishes = 0, ledger = 0
    }

    enum Failure: Error, Equatable { case countsDiffer(expected: Report, found: Report) }

    /// "Copied" is a mark in the store's own metadata, written in the same save as the copied records (Fable S2).
    static let copiedKey = "HeldDearCopiedFromVersion2"

    static func isCopied(_ container: NSPersistentContainer) -> Bool {
        guard let store = container.persistentStoreCoordinator.persistentStores.first else { return false }
        return (container.persistentStoreCoordinator.metadata(for: store)[copiedKey] as? Bool) == true
    }

    /// Reads the mark from a store file without opening it (for a file about to be set aside).
    static func fileSaysCopied(_ url: URL) -> Bool {
        let meta = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: url)
        return (meta?[copiedKey] as? Bool) == true
    }

    private static func setMark(_ on: Bool, _ container: NSPersistentContainer) {
        let coordinator = container.persistentStoreCoordinator
        guard let store = coordinator.persistentStores.first else { return }
        var meta = coordinator.metadata(for: store)
        meta[copiedKey] = on ? true : nil
        coordinator.setMetadata(meta, for: store)
    }

    /// Marks a fresh store as copied with no records, so an older version 2 file is never copied over the user's
    /// latest plans after a version 3 store was set aside. Writes the metadata alone.
    static func markCopiedWithoutRecords(_ container: NSPersistentContainer) {
        setMark(true, container)
        let request = NSSaveChangesRequest(inserted: nil, updated: nil, deleted: nil, locked: nil)
        _ = try? container.persistentStoreCoordinator.execute(request, with: container.viewContext)
    }

    enum CheckFailure: Error, Equatable { case readBackDiffers(String) }

    /// The ids and links of every record, for comparing the old store with the new one (Fable S4).
    struct Shape: Equatable {
        var people: [UUID: [Int]] = [:]          // occasions, wishes, ledger
        var occasions: [UUID: UUID?] = [:]       // person
        var moments: [UUID: UUID?] = [:]         // occasion
        var acts: [UUID: UUID?] = [:]            // moment
        var wishes: [UUID: UUID?] = [:]          // person
        var ledger: [UUID: UUID?] = [:]          // person
    }

    static func shape(of old: SwiftData.ModelContext) throws -> Shape {
        var s = Shape()
        for p in try old.fetch(SwiftData.FetchDescriptor<SchemaV2.Person>()) { s.people[p.id] = [p.occasions.count, p.wishes.count, p.ledger.count] }
        for o in try old.fetch(SwiftData.FetchDescriptor<SchemaV2.Occasion>()) { s.occasions[o.id] = o.person?.id }
        for m in try old.fetch(SwiftData.FetchDescriptor<SchemaV2.Moment>()) { s.moments[m.id] = m.occasion?.id }
        for a in try old.fetch(SwiftData.FetchDescriptor<SchemaV2.Act>()) { s.acts[a.id] = a.moment?.id }
        for w in try old.fetch(SwiftData.FetchDescriptor<SchemaV2.Wish>()) { s.wishes[w.id] = w.person?.id }
        for l in try old.fetch(SwiftData.FetchDescriptor<SchemaV2.LedgerEntry>()) { s.ledger[l.id] = l.person?.id }
        return s
    }

    static func shape(of new: ModelContext) throws -> Shape {
        var s = Shape()
        for p in try new.fetch(FetchDescriptor<Person>()) { s.people[p.id] = [p.occasions.count, p.wishes.count, p.ledger.count] }
        for o in try new.fetch(FetchDescriptor<Occasion>()) { s.occasions[o.id] = o.person?.id }
        for m in try new.fetch(FetchDescriptor<Moment>()) { s.moments[m.id] = m.occasion?.id }
        for a in try new.fetch(FetchDescriptor<Act>()) { s.acts[a.id] = a.moment?.id }
        for w in try new.fetch(FetchDescriptor<Wish>()) { s.wishes[w.id] = w.person?.id }
        for l in try new.fetch(FetchDescriptor<LedgerEntry>()) { s.ledger[l.id] = l.person?.id }
        return s
    }

    /// Copies, checks counts, saves the records and the mark together, then reads everything back in a fresh
    /// context and compares ids and links with the old store. Any failure leaves the new store empty and unmarked.
    @discardableResult
    static func copy(from old: SwiftData.ModelContext, to container: ModelContainer,
                     addresses: SavedAddresses = .shared,
                     beforeSave: ((ModelContext) throws -> Void)? = nil) throws -> Report {
        let new = container.mainContext
        let report: Report
        do {
            report = try insertAll(from: old, into: new, addresses: addresses)
            try beforeSave?(new)
            let found = try counts(new)
            guard found == report else { throw Failure.countsDiffer(expected: report, found: found) }
            setMark(true, container.persistent)
            try new.save()
        } catch {
            new.moc.rollback()
            setMark(false, container.persistent)
            throw error
        }
        let expected = try shape(of: old)
        let fresh = ModelContext(container)
        let readBack = try shape(of: fresh)
        guard readBack == expected else {
            wipe(container)
            throw CheckFailure.readBackDiffers("ids or links differ after the copy")
        }
        return report
    }

    static func counts(_ c: ModelContext) throws -> Report {
        Report(people: try c.fetchCount(FetchDescriptor<Person>()), occasions: try c.fetchCount(FetchDescriptor<Occasion>()),
               moments: try c.fetchCount(FetchDescriptor<Moment>()), acts: try c.fetchCount(FetchDescriptor<Act>()),
               wishes: try c.fetchCount(FetchDescriptor<Wish>()), ledger: try c.fetchCount(FetchDescriptor<LedgerEntry>()))
    }

    /// Empties the new store and removes the mark, after a copy that didn't read back right. Only the new store.
    static func wipe(_ container: ModelContainer) {
        let c = ModelContext(container)
        for name in ["Act", "Wish", "LedgerEntry", "Moment", "Occasion", "Person"] {
            let found = (try? c.moc.fetch(NSFetchRequest<NSManagedObject>(entityName: name))) ?? []
            found.forEach { c.moc.delete($0) }
        }
        setMark(false, container.persistent)
        try? c.save()
        container.mainContext.moc.reset()
    }

    private static func insertAll(from old: SwiftData.ModelContext, into new: ModelContext,
                                  addresses: SavedAddresses) throws -> Report {
        let people = try old.fetch(SwiftData.FetchDescriptor<SchemaV2.Person>())
        let occasions = try old.fetch(SwiftData.FetchDescriptor<SchemaV2.Occasion>())
        let moments = try old.fetch(SwiftData.FetchDescriptor<SchemaV2.Moment>())
        let acts = try old.fetch(SwiftData.FetchDescriptor<SchemaV2.Act>())
        let wishes = try old.fetch(SwiftData.FetchDescriptor<SchemaV2.Wish>())
        let ledger = try old.fetch(SwiftData.FetchDescriptor<SchemaV2.LedgerEntry>())
        let expected = Report(people: people.count, occasions: occasions.count, moments: moments.count,
                              acts: acts.count, wishes: wishes.count, ledger: ledger.count)

        var personByID: [UUID: Person] = [:]
        for o in people {
            let p = Person(name: o.name, fullName: o.fullName, contactID: o.contactID, ring: .outer)
            p.id = o.id
            p.manualPhone = o.manualPhone
            p.ringRaw = o.ringRaw
            p.photoFiles = o.photoFiles
            p.createdAt = o.createdAt
            p.showAgeOnCard = o.showAgeOnCard
            p.loves = o.loves
            p.sizes = o.sizes
            p.goodToKnow = o.goodToKnow
            p.relationship = o.relationship
            p.mailingAddress = addresses.address(for: o.id)
            new.insert(p)
            personByID[o.id] = p
        }
        var occasionByID: [UUID: Occasion] = [:]
        for o in occasions {
            let c = Occasion(type: .birthday, month: o.month, day: o.day, birthYear: o.birthYear)
            c.id = o.id
            c.typeRaw = o.typeRaw
            c.ringOverrideRaw = o.ringOverrideRaw
            c.extraRecipientIDs = o.extraRecipientIDs
            c.partnerName = o.partnerName
            new.insert(c)
            c.person = o.person.flatMap { personByID[$0.id] }
            occasionByID[o.id] = c
        }
        var momentByID: [UUID: Moment] = [:]
        for o in moments {
            let m = Moment(year: o.year, dueDate: o.dueDate)
            m.id = o.id
            m.statusRaw = o.statusRaw
            m.headsUpAt = o.headsUpAt
            m.callStartedAt = o.callStartedAt
            m.photoPromptShown = o.photoPromptShown
            m.missedAt = o.missedAt
            m.familyPageID = o.familyPageID
            m.familyOwnerKey = o.familyOwnerKey
            m.familyInviteURL = o.familyInviteURL
            m.familyGiftURL = o.familyGiftURL
            new.insert(m)
            m.occasion = o.occasion.flatMap { occasionByID[$0.id] }
            momentByID[o.id] = m
        }
        for o in acts {
            let a = Act(role: .plan, kind: .other, title: o.title, wishID: o.wishID)
            a.id = o.id
            a.roleRaw = o.roleRaw
            a.kindRaw = o.kindRaw
            a.fromNote = o.fromNote
            a.dinnerDate = o.dinnerDate
            a.arrivesBy = o.arrivesBy
            a.photoFile = o.photoFile
            a.cardFile = o.cardFile
            a.completedAt = o.completedAt
            a.confirmedRaw = o.confirmedRaw
            a.createdAt = o.createdAt
            a.label = o.label
            a.step = o.step
            a.ownerIDs = o.ownerIDs
            a.note = o.note
            a.sortOrder = o.sortOrder
            new.insert(a)
            a.moment = o.moment.flatMap { momentByID[$0.id] }
        }
        for o in wishes {
            let w = Wish(text: o.text, url: o.url, imageFile: o.imageFile, capturedAt: o.capturedAt)
            w.id = o.id
            w.statusRaw = o.statusRaw
            new.insert(w)
            w.person = o.person.flatMap { personByID[$0.id] }
        }
        for o in ledger {
            let l = LedgerEntry(year: o.year, type: .birthday, what: o.what, photoFile: o.photoFile, line: o.line,
                                personName: o.personName, momentID: o.momentID)
            l.id = o.id
            l.occasionTypeRaw = o.occasionTypeRaw
            l.cardFile = o.cardFile
            l.createdAt = o.createdAt
            new.insert(l)
            l.person = o.person.flatMap { personByID[$0.id] }
        }

        return expected
    }
}
