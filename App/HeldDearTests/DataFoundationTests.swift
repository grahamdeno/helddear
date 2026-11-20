import XCTest
import SwiftData
@testable import HeldDear

/// Data foundation for 1.0 (roadmap Epic 2, Data): new fields, part steps, versioned schema, migration, safe open.
/// Test names start with the requirement they cover (M1 to M4, Steps, Fields).
final class DataFoundationTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appending(path: "HeldDearTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func facts(_ kind: ActKind, role: ActRole = .plan, step: String? = nil, completed: Bool = false,
                       arrivesBy: Bool = false, title: Bool = false, wish: Bool = false,
                       dinnerDate: Bool = false) -> PartSteps.Facts {
        PartSteps.Facts(role: role, kindRaw: kind.rawValue, storedStep: step, completed: completed,
                        hasArrivesBy: arrivesBy, hasTitle: title, hasWish: wish, hasDinnerDate: dinnerDate)
    }

    // MARK: Steps: lists

    func testSteps_listsPerKindEndInTheirReadyStep() {
        XCTAssertEqual(PartSteps.steps(for: .buy), ["open", "idea", "bought", "wrapped"])
        XCTAssertEqual(PartSteps.steps(for: .card), ["open", "idea", "written"])
        XCTAssertEqual(PartSteps.steps(for: .make), ["open", "idea", "making", "finished"])
        XCTAssertEqual(PartSteps.steps(for: .day), ["open", "idea", "booked"])
        XCTAssertEqual(PartSteps.steps(for: .orderAhead), ["open", "idea", "ordered", "ready"])
        XCTAssertEqual(PartSteps.steps(for: .callOrMessage), ["open", "done"])
        XCTAssertEqual(PartSteps.steps(for: .other), ["open", "idea", "ready"])
        for family in PartSteps.Family.allCases {
            XCTAssertEqual(PartSteps.steps(for: family).first, "open")
            XCTAssertEqual(PartSteps.readyStep(for: family), PartSteps.steps(for: family).last)
        }
    }

    func testSteps_readyOnlyAtTheLastStep() {
        XCTAssertTrue(PartSteps.isReady(step: "wrapped", family: .buy))
        XCTAssertFalse(PartSteps.isReady(step: "bought", family: .buy))
        XCTAssertTrue(PartSteps.isReady(step: "ready", family: .other))
        XCTAssertFalse(PartSteps.isReady(step: "idea", family: .other))
        XCTAssertTrue(PartSteps.isReady(step: "done", family: .callOrMessage))
    }

    func testSteps_storedKindsMapToTheirFamily() {
        XCTAssertEqual(PartSteps.family(forKindRaw: "gift"), .buy)
        XCTAssertEqual(PartSteps.family(forKindRaw: "card"), .card)
        XCTAssertEqual(PartSteps.family(forKindRaw: "dinner"), .day)
        XCTAssertEqual(PartSteps.family(forKindRaw: "call"), .callOrMessage)
        XCTAssertEqual(PartSteps.family(forKindRaw: "message"), .callOrMessage)
        XCTAssertEqual(PartSteps.family(forKindRaw: "other"), .other)
        XCTAssertEqual(PartSteps.family(forKindRaw: "unknown-kind"), .other, "Unknown kinds read as other, like ActKind")
    }

    // MARK: Steps: rules for existing parts

    func testSteps_gift() {
        XCTAssertEqual(PartSteps.currentStep(facts(.gift, completed: true, arrivesBy: true, title: true)), "wrapped")
        XCTAssertEqual(PartSteps.currentStep(facts(.gift, arrivesBy: true, title: true)), "bought")
        XCTAssertEqual(PartSteps.currentStep(facts(.gift, title: true)), "idea")
        XCTAssertEqual(PartSteps.currentStep(facts(.gift, wish: true)), "idea")
        XCTAssertEqual(PartSteps.currentStep(facts(.gift)), "open")
    }

    func testSteps_card() {
        XCTAssertEqual(PartSteps.currentStep(facts(.card, completed: true)), "written")
        XCTAssertEqual(PartSteps.currentStep(facts(.card)), "open")
        XCTAssertEqual(PartSteps.currentStep(facts(.card, title: true)), "open", "A card's title doesn't make it an idea")
    }

    func testSteps_dinner() {
        XCTAssertEqual(PartSteps.currentStep(facts(.dinner, dinnerDate: true)), "booked")
        XCTAssertEqual(PartSteps.currentStep(facts(.dinner, completed: true)), "booked")
        XCTAssertEqual(PartSteps.currentStep(facts(.dinner)), "open")
    }

    func testSteps_callAndMessage() {
        XCTAssertEqual(PartSteps.currentStep(facts(.call, completed: true)), "done")
        XCTAssertEqual(PartSteps.currentStep(facts(.call)), "open")
        XCTAssertEqual(PartSteps.currentStep(facts(.message, completed: true)), "done")
        XCTAssertEqual(PartSteps.currentStep(facts(.message)), "open")
    }

    func testSteps_other() {
        XCTAssertEqual(PartSteps.currentStep(facts(.other, completed: true, title: true)), "ready")
        XCTAssertEqual(PartSteps.currentStep(facts(.other, title: true)), "idea")
        XCTAssertEqual(PartSteps.currentStep(facts(.other)), "open")
    }

    func testSteps_greetingsAreNotParts() {
        XCTAssertNil(PartSteps.currentStep(facts(.message, role: .greeting, completed: true)))
        XCTAssertNil(PartSteps.currentStep(facts(.call, role: .greeting)))
    }

    func testSteps_userPickedStepWins() {
        XCTAssertEqual(PartSteps.currentStep(facts(.gift, step: "idea", completed: true)), "idea")
        XCTAssertEqual(PartSteps.currentStep(facts(.card, step: "idea")), "idea")
        // A stored step that isn't in the kind's list is ignored and the step is worked out instead.
        XCTAssertEqual(PartSteps.currentStep(facts(.card, step: "wrapped", completed: true)), "written")
    }

    func testSteps_actReadsItsStepAndReadiness() {
        let gift = Act(role: .plan, kind: .gift, title: "Garden gloves")
        XCTAssertEqual(gift.currentStep, "idea")
        XCTAssertFalse(gift.isReady)
        gift.complete(.user)
        XCTAssertEqual(gift.currentStep, "wrapped")
        XCTAssertTrue(gift.isReady)
        XCTAssertNil(gift.step, "Reading the step never stores it")
        XCTAssertNil(Act(role: .greeting, kind: .message).currentStep)
    }

    // MARK: Fields

    func testFields_newFieldsHaveDefaultsAndSave() throws {
        let opened = Store.open(inMemory: true)
        let context = ModelContext(opened.container)
        let person = Person(name: "Mom")
        let act = Act(role: .plan, kind: .gift)
        context.insert(person)
        context.insert(act)
        XCTAssertNil(person.relationship)
        XCTAssertNil(act.label)
        XCTAssertNil(act.step)
        XCTAssertEqual(act.ownerIDs, [], "Empty means You")
        XCTAssertNil(act.note)
        XCTAssertEqual(act.sortOrder, 0)

        let owner = UUID()
        person.relationship = "mother"
        act.label = "Breakfast in bed"
        act.step = "bought"
        act.ownerIDs = [owner]
        act.note = "arrives Dec 12"
        act.sortOrder = 3
        try context.save()

        let again = ModelContext(opened.container)
        let p = try XCTUnwrap(again.fetch(FetchDescriptor<Person>()).first)
        let a = try XCTUnwrap(again.fetch(FetchDescriptor<Act>()).first)
        XCTAssertEqual(p.relationship, "mother")
        XCTAssertEqual(a.label, "Breakfast in bed")
        XCTAssertEqual(a.step, "bought")
        XCTAssertEqual(a.ownerIDs, [owner])
        XCTAssertEqual(a.note, "arrives Dec 12")
        XCTAssertEqual(a.sortOrder, 3)
        XCTAssertEqual(a.currentStep, "bought")
    }

    // MARK: M1. Versioned schema

    func testM1_versionsAndOneLightweightStage() {
        XCTAssertEqual(SchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(SchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
        XCTAssertEqual(HeldDearMigrationPlan.schemas.map { ObjectIdentifier($0) },
                       [ObjectIdentifier(SchemaV1.self), ObjectIdentifier(SchemaV2.self)])
        XCTAssertEqual(HeldDearMigrationPlan.stages.count, 1)
        guard case .lightweight(let from, let to) = HeldDearMigrationPlan.stages[0] else {
            return XCTFail("The 1 to 2 stage must be lightweight")
        }
        XCTAssertEqual(ObjectIdentifier(from), ObjectIdentifier(SchemaV1.self))
        XCTAssertEqual(ObjectIdentifier(to), ObjectIdentifier(SchemaV2.self))
    }

    func testM1_entityNamesMatchTheStoreOnPhonesToday() {
        // Stores made before versioning use the plain class names. Both versions must keep them.
        let names: Set = ["Person", "Occasion", "Moment", "Wish", "Act", "LedgerEntry"]
        XCTAssertEqual(Set(Schema(versionedSchema: SchemaV1.self).entities.map(\.name)), names)
        XCTAssertEqual(Set(Schema(versionedSchema: SchemaV2.self).entities.map(\.name)), names)
    }

    func testM1_versionTwoOnlyAddsTheNewFields() {
        func attributes(_ schema: Schema, _ entity: String) -> Set<String> {
            Set(schema.entities.first { $0.name == entity }?.attributes.map(\.name) ?? [])
        }
        let v1 = Schema(versionedSchema: SchemaV1.self)
        let v2 = Schema(versionedSchema: SchemaV2.self)
        XCTAssertEqual(attributes(v2, "Act").subtracting(attributes(v1, "Act")),
                       ["label", "step", "ownerIDs", "note", "sortOrder"])
        XCTAssertEqual(attributes(v2, "Person").subtracting(attributes(v1, "Person")), ["relationship"])
        for entity in ["Person", "Occasion", "Moment", "Wish", "Act", "LedgerEntry"] {
            XCTAssertTrue(attributes(v1, entity).isSubset(of: attributes(v2, entity)), "\(entity) lost a field")
        }
        for entity in ["Occasion", "Moment", "Wish", "LedgerEntry"] {
            XCTAssertEqual(attributes(v1, entity), attributes(v2, entity), "\(entity) changed")
        }
    }

    func testM1_storeOpensThroughTheMigrationPlan() throws {
        let opened = Store.open(url: dir.appending(path: "default.store"))
        XCTAssertFalse(opened.couldNotOpenSavedStore)
        XCTAssertNil(opened.keptStoreURL)
        XCTAssertEqual(opened.container.schema.entities.count, 6)
    }

    // MARK: M2. Migration from version 1

    private struct V1Fixture {
        var people: [UUID] = []
        var occasions: [UUID] = []
        var moments: [UUID] = []
        var wish: UUID!
        var ledger: UUID!
        /// Act id → the step it must read after migration (nil for the greeting).
        var expectedSteps: [UUID: String?] = [:]
        var giftArrivesBy: Date!
        var dinnerDate: Date!
        var cardCompletedAt: Date!
    }

    /// Writes a version 1 store with sample data from current builds, then closes it.
    private func writeV1Store(at url: URL) throws -> V1Fixture {
        var fx = V1Fixture()
        let schema = Schema(versionedSchema: SchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let context = ModelContext(container)

        let mom = SchemaV1.Person(name: "Mom", fullName: "Ann Lee", contactID: "contact-1", ring: .inner)
        mom.loves = ["gardening"]
        let sam = SchemaV1.Person(name: "Sam")
        let momBirthday = SchemaV1.Occasion(type: .birthday, month: 3, day: 14, birthYear: 1958)
        let samBirthday = SchemaV1.Occasion(type: .birthday, month: 7, day: 2)
        let momChristmas = SchemaV1.Occasion(type: .christmas, month: 12, day: 25)
        momBirthday.person = mom
        samBirthday.person = sam
        momChristmas.person = mom

        let cal = Calendar(identifier: .gregorian)
        let birthdayMoment = SchemaV1.Moment(year: 2027, dueDate: cal.date(from: DateComponents(year: 2027, month: 3, day: 14))!)
        let samMoment = SchemaV1.Moment(year: 2027, dueDate: cal.date(from: DateComponents(year: 2027, month: 7, day: 2))!)
        let christmasMoment = SchemaV1.Moment(year: 2026, dueDate: cal.date(from: DateComponents(year: 2026, month: 12, day: 25))!)
        birthdayMoment.occasion = momBirthday
        samMoment.occasion = samBirthday
        christmasMoment.occasion = momChristmas

        fx.giftArrivesBy = cal.date(from: DateComponents(year: 2027, month: 3, day: 10))!
        fx.dinnerDate = cal.date(from: DateComponents(year: 2027, month: 7, day: 2, hour: 19))!
        fx.cardCompletedAt = cal.date(from: DateComponents(year: 2027, month: 3, day: 1))!

        let wish = SchemaV1.Wish(text: "Garden gloves", url: "https://example.com/gloves")
        wish.person = mom
        let gift = SchemaV1.Act(role: .plan, kind: .gift, title: "Garden gloves", wishID: wish.id)
        gift.arrivesBy = fx.giftArrivesBy
        let card = SchemaV1.Act(role: .plan, kind: .card)
        card.complete(.user, at: fx.cardCompletedAt)
        let greeting = SchemaV1.Act(role: .greeting, kind: .message)
        greeting.complete(.messageSent)
        let dinner = SchemaV1.Act(role: .plan, kind: .dinner)
        dinner.dinnerDate = fx.dinnerDate
        let call = SchemaV1.Act(role: .plan, kind: .call)
        let other = SchemaV1.Act(role: .plan, kind: .other, title: "Ornament with the kids' handprints")
        other.complete(.user)
        for act in [gift, card, greeting] { act.moment = birthdayMoment }
        for act in [dinner, call] { act.moment = samMoment }
        other.moment = christmasMoment

        let line = SchemaV1.LedgerEntry(year: 2026, type: .birthday, what: "Card and a call", photoFile: nil,
                                        line: "Laughed about the garden", personName: "Mom", momentID: nil)
        line.person = mom

        for p in [mom, sam] { context.insert(p) }
        for o in [momBirthday, samBirthday, momChristmas] { context.insert(o) }
        for m in [birthdayMoment, samMoment, christmasMoment] { context.insert(m) }
        for a in [gift, card, greeting, dinner, call, other] { context.insert(a) }
        context.insert(wish)
        context.insert(line)
        try context.save()

        fx.people = [mom.id, sam.id]
        fx.occasions = [momBirthday.id, samBirthday.id, momChristmas.id]
        fx.moments = [birthdayMoment.id, samMoment.id, christmasMoment.id]
        fx.wish = wish.id
        fx.ledger = line.id
        fx.expectedSteps = [gift.id: "bought", card.id: "written", greeting.id: nil,
                            dinner.id: "booked", call.id: "open", other.id: "ready"]
        return fx
    }

    func testM2_versionOneStoreMigratesWithEveryRecordAndStep() throws {
        let url = dir.appending(path: "default.store")
        let fx = try writeV1Store(at: url)

        let opened = Store.open(url: url)
        XCTAssertFalse(opened.couldNotOpenSavedStore, "A version 1 store must migrate, not be kept aside")
        let context = ModelContext(opened.container)

        let people = try context.fetch(FetchDescriptor<Person>())
        XCTAssertEqual(Set(people.map(\.id)), Set(fx.people))
        let mom = try XCTUnwrap(people.first { $0.name == "Mom" })
        XCTAssertEqual(mom.fullName, "Ann Lee")
        XCTAssertEqual(mom.contactID, "contact-1")
        XCTAssertEqual(mom.ring, .inner)
        XCTAssertEqual(mom.loves, ["gardening"])
        XCTAssertNil(mom.relationship)
        XCTAssertEqual(Set(mom.occasions.map(\.type)), [.birthday, .christmas])

        let occasions = try context.fetch(FetchDescriptor<Occasion>())
        XCTAssertEqual(Set(occasions.map(\.id)), Set(fx.occasions))
        XCTAssertEqual(occasions.first { $0.type == .birthday && $0.person?.name == "Mom" }?.birthYear, 1958)

        let moments = try context.fetch(FetchDescriptor<Moment>())
        XCTAssertEqual(Set(moments.map(\.id)), Set(fx.moments))

        let acts = try context.fetch(FetchDescriptor<Act>())
        XCTAssertEqual(Set(acts.map(\.id)), Set(fx.expectedSteps.keys))
        for act in acts {
            XCTAssertEqual(act.currentStep, fx.expectedSteps[act.id] ?? nil, "\(act.kindRaw) \(act.roleRaw)")
            XCTAssertNil(act.label)
            XCTAssertNil(act.step)
            XCTAssertEqual(act.ownerIDs, [])
            XCTAssertNil(act.note)
            XCTAssertEqual(act.sortOrder, 0)
            XCTAssertNotNil(act.moment, "Every part keeps its moment")
        }
        let gift = try XCTUnwrap(acts.first { $0.kind == .gift })
        XCTAssertEqual(gift.arrivesBy, fx.giftArrivesBy)
        XCTAssertEqual(gift.wishID, fx.wish)
        XCTAssertEqual(acts.first { $0.kind == .dinner }?.dinnerDate, fx.dinnerDate)
        XCTAssertEqual(acts.first { $0.kind == .card }?.completedAt, fx.cardCompletedAt)

        let wishes = try context.fetch(FetchDescriptor<Wish>())
        XCTAssertEqual(wishes.map(\.id), [fx.wish])
        XCTAssertEqual(wishes.first?.person?.name, "Mom")
        XCTAssertEqual(wishes.first?.text, "Garden gloves")

        let ledger = try context.fetch(FetchDescriptor<LedgerEntry>())
        XCTAssertEqual(ledger.map(\.id), [fx.ledger])
        XCTAssertEqual(ledger.first?.line, "Laughed about the garden")
        XCTAssertEqual(ledger.first?.person?.name, "Mom")
    }

    // MARK: M3. Never crash on open

    func testM3_unreadableStoreIsKeptAsideAndAFreshStoreOpens() throws {
        let url = dir.appending(path: "default.store")
        let junk = Data("This is not a Held Dear store.".utf8)
        try junk.write(to: url)
        let now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 13, minute: 15))!

        let opened = Store.open(url: url, now: now)

        XCTAssertTrue(opened.couldNotOpenSavedStore)
        let kept = try XCTUnwrap(opened.keptStoreURL)
        XCTAssertEqual(kept.deletingLastPathComponent().standardizedFileURL, dir.standardizedFileURL, "Kept next to the original")
        XCTAssertTrue(kept.lastPathComponent.hasPrefix("default-kept-2026-11-20-"), kept.lastPathComponent)
        XCTAssertEqual(try Data(contentsOf: kept), junk, "The old file is untouched")

        // The fresh store is a real one at the usual place, and it saves.
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let context = ModelContext(opened.container)
        context.insert(Person(name: "Mom"))
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Person>()), 1)

        // Opening again uses the fresh store and keeps nothing else aside.
        let second = Store.open(url: url, now: now)
        XCTAssertFalse(second.couldNotOpenSavedStore)
        XCTAssertEqual(try ModelContext(second.container).fetchCount(FetchDescriptor<Person>()), 1)
    }

    func testM3_keepAsideNeverOverwritesAnEarlierKeptFile() throws {
        let url = dir.appending(path: "default.store")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try Data("first".utf8).write(to: url)
        let first = try Store.keepAside(url, now: now)
        try Data("second".utf8).write(to: url)
        let second = try Store.keepAside(url, now: now)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try Data(contentsOf: first), Data("first".utf8))
        XCTAssertEqual(try Data(contentsOf: second), Data("second".utf8))
    }

    // MARK: M4. No bulk rewrite

    func testM4_openingAndReadingAMigratedStoreWritesNothingToParts() throws {
        let url = dir.appending(path: "default.store")
        let fx = try writeV1Store(at: url)

        do {
            let opened = Store.open(url: url)
            let context = ModelContext(opened.container)
            let acts = try context.fetch(FetchDescriptor<Act>())
            XCTAssertEqual(acts.count, fx.expectedSteps.count)
            for act in acts {
                _ = act.currentStep
                _ = act.isReady
            }
            XCTAssertFalse(context.hasChanges, "Reading steps must not change any part")
            XCTAssertTrue(acts.allSatisfy { $0.step == nil })
        }

        // Reopen: still nothing stored for any part's step.
        let reopened = Store.open(url: url)
        let acts = try ModelContext(reopened.container).fetch(FetchDescriptor<Act>())
        XCTAssertEqual(acts.count, fx.expectedSteps.count)
        XCTAssertTrue(acts.allSatisfy { $0.step == nil }, "No step was written for existing parts")
    }
}
