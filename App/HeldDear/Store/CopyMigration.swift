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

    /// A small file next to the store says the store is complete (copied, or started fresh).
    static func markerURL(_ storeURL: URL) -> URL { URL(fileURLWithPath: storeURL.path + ".complete") }

    static func isComplete(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: markerURL(url).path) }

    static func markComplete(_ container: NSPersistentContainer) {
        guard let url = container.persistentStoreDescriptions.first?.url, url.path != "/dev/null" else { return }
        FileManager.default.createFile(atPath: markerURL(url).path, contents: Data(CoreStore.version.utf8))
    }

    @discardableResult
    static func copy(from old: SwiftData.ModelContext, to new: ModelContext,
                     addresses: SavedAddresses = .shared) throws -> Report {
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

        let found = Report(people: try new.fetchCount(FetchDescriptor<Person>()),
                           occasions: try new.fetchCount(FetchDescriptor<Occasion>()),
                           moments: try new.fetchCount(FetchDescriptor<Moment>()),
                           acts: try new.fetchCount(FetchDescriptor<Act>()),
                           wishes: try new.fetchCount(FetchDescriptor<Wish>()),
                           ledger: try new.fetchCount(FetchDescriptor<LedgerEntry>()))
        guard found == expected else { throw Failure.countsDiffer(expected: expected, found: found) }
        try new.save()
        return found
    }
}
