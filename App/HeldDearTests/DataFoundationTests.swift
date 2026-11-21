import XCTest
import SwiftData
import Observation
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
        XCTAssertEqual(PartSteps.steps(for: .other), ["open", "idea", "ordered", "scheduled", "bought", "ready"])
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
        // Any status from the full list is kept, even outside the kind's own list; an unknown one is ignored.
        XCTAssertEqual(PartSteps.currentStep(facts(.card, step: "wrapped", completed: true)), "wrapped")
        XCTAssertEqual(PartSteps.currentStep(facts(.card, step: "nonsense", completed: true)), "written")
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
        let context = HeldDear.ModelContext(opened.container)
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

        let again = HeldDear.ModelContext(opened.container)
        let p = try XCTUnwrap(again.fetch(HeldDear.FetchDescriptor<Person>()).first)
        let a = try XCTUnwrap(again.fetch(HeldDear.FetchDescriptor<Act>()).first)
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

    func testM1_versionThreeStoreOpensWithSixRecordTypes() throws {
        let opened = Store.open(url: dir.appending(path: "HeldDear.sqlite"), copyFromLegacy: false)
        XCTAssertEqual(opened.outcome, .opened)
        XCTAssertNil(opened.keptStoreURL)
        XCTAssertEqual(Set(CoreStore.model.entities.compactMap(\.name)),
                       ["Person", "Occasion", "Moment", "Wish", "Act", "LedgerEntry", "Photo"], "Six record types plus Photo (3.1)")
    }

    func testV3_iCloudReadyModel() {
        // Item 3.0: no unique ids, every field optional or defaulted, every link optional.
        for entity in CoreStore.model.entities {
            XCTAssertTrue(entity.uniquenessConstraints.isEmpty, "\(entity.name ?? "") has a unique rule")
            for (name, attr) in entity.attributesByName {
                XCTAssertTrue(attr.isOptional || attr.defaultValue != nil, "\(entity.name ?? "").\(name)")
            }
            for (name, rel) in entity.relationshipsByName {
                XCTAssertTrue(rel.isOptional, "\(entity.name ?? "").\(name) must be optional")
                XCTAssertNotNil(rel.inverseRelationship, "\(entity.name ?? "").\(name) needs an inverse")
            }
        }
        // Every version 2 field is still there, with the same name.
        let v2 = Schema(versionedSchema: SchemaV2.self)
        for entity in v2.entities {
            let v3 = Set(CoreStore.model.entitiesByName[entity.name]?.attributesByName.keys.map { $0 } ?? [])
            XCTAssertTrue(Set(entity.attributes.map(\.name)).isSubset(of: v3), "\(entity.name) lost a field")
        }
        XCTAssertNotNil(CoreStore.model.entitiesByName["Person"]?.attributesByName["mailingAddress"])
    }

    func testM1_productionStoreLivesWhereMainOpenedIt() {
        // Main opened the store with ModelConfiguration(schema:isStoredInMemoryOnly:), which leaves the group container
        // on .automatic, so a signed install keeps the store in the App Group container. Version 2 must resolve to the
        // same file, or an upgrade would open an empty store. (CI is unsigned and resolves both to Application Support;
        // the equality is what matters. A signed device is the other check.)
        let theWayMainOpenedIt = ModelConfiguration(schema: Schema(versionedSchema: SchemaV1.self), isStoredInMemoryOnly: false)
        XCTAssertEqual(LegacyStore.productionConfiguration().url, theWayMainOpenedIt.url)
        XCTAssertEqual(LegacyStore.productionURL, theWayMainOpenedIt.url)
        XCTAssertEqual(LegacyStore.productionConfiguration().url,
                       ModelConfiguration(schema: LegacyStore.schema).url,
                       "Same place as the plain configuration for the current schema")
        XCTAssertEqual(LegacyStore.productionURL.lastPathComponent, "default.store")
        let custom = dir.appending(path: "elsewhere.store")
        XCTAssertEqual(LegacyStore.configuration(url: custom).url, custom, "A url is honored for tests")
        // Version 3 sits next to it, so the copy finds the old store.
        XCTAssertEqual(Store.productionURL.deletingLastPathComponent(), LegacyStore.productionURL.deletingLastPathComponent())
        XCTAssertEqual(Store.productionURL.lastPathComponent, "HeldDear.sqlite")
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
        let container = try SwiftData.ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let context = SwiftData.ModelContext(container)

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

        let opened = Store.open(url: dir.appending(path: "HeldDear.sqlite"), legacyURL: url)
        XCTAssertEqual(opened.outcome, .opened, "A version 1 store must migrate, not be kept aside")
        XCTAssertEqual(opened.copy, CopyMigration.Report(people: 2, occasions: 3, moments: 3, acts: 6, wishes: 1, ledger: 1))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "The old store stays where it was")
        let context = HeldDear.ModelContext(opened.container)

        let people = try context.fetch(HeldDear.FetchDescriptor<Person>())
        XCTAssertEqual(Set(people.map(\.id)), Set(fx.people))
        let mom = try XCTUnwrap(people.first { $0.name == "Mom" })
        XCTAssertEqual(mom.fullName, "Ann Lee")
        XCTAssertEqual(mom.contactID, "contact-1")
        XCTAssertEqual(mom.ring, .inner)
        XCTAssertEqual(mom.loves, ["gardening"])
        XCTAssertNil(mom.relationship)
        XCTAssertEqual(Set(mom.occasions.map(\.type)), [.birthday, .christmas])

        let occasions = try context.fetch(HeldDear.FetchDescriptor<Occasion>())
        XCTAssertEqual(Set(occasions.map(\.id)), Set(fx.occasions))
        XCTAssertEqual(occasions.first { $0.type == .birthday && $0.person?.name == "Mom" }?.birthYear, 1958)

        let moments = try context.fetch(HeldDear.FetchDescriptor<Moment>())
        XCTAssertEqual(Set(moments.map(\.id)), Set(fx.moments))

        let acts = try context.fetch(HeldDear.FetchDescriptor<Act>())
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

        let wishes = try context.fetch(HeldDear.FetchDescriptor<Wish>())
        XCTAssertEqual(wishes.map(\.id), [fx.wish])
        XCTAssertEqual(wishes.first?.person?.name, "Mom")
        XCTAssertEqual(wishes.first?.text, "Garden gloves")

        let ledger = try context.fetch(HeldDear.FetchDescriptor<LedgerEntry>())
        XCTAssertEqual(ledger.map(\.id), [fx.ledger])
        XCTAssertEqual(ledger.first?.line, "Laughed about the garden")
        XCTAssertEqual(ledger.first?.person?.name, "Mom")
    }

    // MARK: M3. Never crash on open

    func testM3_anOldStoreThatWontOpenIsLeftInPlaceAndTriedAgain() throws {
        // Fable S1: left where it is, not marked, in memory this launch, retried next launch.
        let url = dir.appending(path: "default.store")
        let junk = Data("This is not a Held Dear store.".utf8)
        try junk.write(to: url)
        let v3 = dir.appending(path: "HeldDear.sqlite")

        let opened = Store.open(url: v3, legacyURL: url)
        XCTAssertEqual(opened.outcome, .inMemoryThisLaunch)
        XCTAssertEqual(opened.keptStoreURL, url, "Offered for export where it is")
        XCTAssertEqual(try Data(contentsOf: url), junk, "The old file is untouched")
        XCTAssertFalse(CopyMigration.fileSaysCopied(v3), "Not marked as copied")

        let again = Store.open(url: v3, legacyURL: url)
        XCTAssertEqual(again.outcome, .inMemoryThisLaunch, "Tried again, still left in place")
        XCTAssertEqual(try Data(contentsOf: url), junk)
    }

    func testM3_unreadableVersionThreeStoreIsKeptAsideAndAFreshStoreOpens() throws {
        let v3 = dir.appending(path: "HeldDear.sqlite")
        let junk = Data("This is not a Held Dear store.".utf8)
        try junk.write(to: v3)
        let now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 13, minute: 15))!

        let opened = Store.open(url: v3, copyFromLegacy: false, now: now)

        XCTAssertEqual(opened.outcome, .freshStoreOldKeptAside)
        let kept = try XCTUnwrap(opened.keptStoreURL)
        XCTAssertEqual(kept.deletingLastPathComponent().standardizedFileURL, dir.standardizedFileURL, "Kept next to the original")
        XCTAssertTrue(kept.lastPathComponent.hasPrefix("HeldDear-kept-2026-11-20-"), kept.lastPathComponent)
        XCTAssertEqual(try Data(contentsOf: kept), junk, "The old file is untouched")

        let context = HeldDear.ModelContext(opened.container)
        context.insert(Person(name: "Mom"))
        try context.save()
        XCTAssertEqual(try context.fetchCount(HeldDear.FetchDescriptor<Person>()), 1)

        let second = Store.open(url: v3, copyFromLegacy: false, now: now)
        XCTAssertEqual(second.outcome, .opened)
        XCTAssertEqual(try HeldDear.ModelContext(second.container).fetchCount(HeldDear.FetchDescriptor<Person>()), 1)
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

    func testM3_whenNoFreshFileCanBeOpenedTheAppRunsInMemoryForThisLaunch() throws {
        // A regular file where the store's folder should be: the folder can't be made, and there is no store file to
        // move aside, so neither a kept file nor a fresh file is possible.
        let blocker = dir.appending(path: "blocker")
        try Data("not a folder".utf8).write(to: blocker)
        let url = blocker.appending(path: "HeldDear.sqlite")

        let opened = Store.open(url: url, copyFromLegacy: false)

        XCTAssertEqual(opened.outcome, .inMemoryThisLaunch)
        XCTAssertTrue(opened.couldNotOpenSavedStore)
        XCTAssertNil(opened.keptStoreURL)
        XCTAssertEqual(try Data(contentsOf: blocker), Data("not a folder".utf8), "Nothing else was touched")
        // It still runs: this launch can read and write, in memory only.
        let context = HeldDear.ModelContext(opened.container)
        context.insert(Person(name: "Mom"))
        try context.save()
        XCTAssertEqual(try context.fetchCount(HeldDear.FetchDescriptor<Person>()), 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "Nothing was written to disk")
    }

    // MARK: M4. No bulk rewrite

    func testM4_openingAndReadingAMigratedStoreWritesNothingToParts() throws {
        let url = dir.appending(path: "default.store")
        let fx = try writeV1Store(at: url)

        let v3 = dir.appending(path: "HeldDear.sqlite")
        do {
            let opened = Store.open(url: v3, legacyURL: url)
            let context = HeldDear.ModelContext(opened.container)
            let acts = try context.fetch(HeldDear.FetchDescriptor<Act>())
            XCTAssertEqual(acts.count, fx.expectedSteps.count)
            for act in acts {
                _ = act.currentStep
                _ = act.isReady
            }
            XCTAssertFalse(context.hasChanges, "Reading steps must not change any part")
            XCTAssertTrue(acts.allSatisfy { $0.step == nil })
        }

        // Reopen: still nothing stored for any part's step.
        let reopened = Store.open(url: v3, legacyURL: url)
        XCTAssertNil(reopened.copy, "The copy runs once")
        let acts = try HeldDear.ModelContext(reopened.container).fetch(HeldDear.FetchDescriptor<Act>())
        XCTAssertEqual(acts.count, fx.expectedSteps.count, "Nothing was copied twice")
        XCTAssertTrue(acts.allSatisfy { $0.step == nil }, "No step was written for existing parts")
    }

    // MARK: Version 3 (Core Data)

    func testV3_copyMovesAKeptAddressOntoThePerson() throws {
        let url = dir.appending(path: "default.store")
        let fx = try writeV1Store(at: url)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "V3AddressTests"))
        defaults.removePersistentDomain(forName: "V3AddressTests")
        let addresses = SavedAddresses(defaults: defaults)
        addresses.set(MailAddress(firstName: "Ann", address1: "1 Main St", city: "Springfield", state: "IL", zip: "62701"),
                      for: fx.people[0])
        let legacy = try LegacyStore.container(url: url)
        let opened = Store.open(url: dir.appending(path: "HeldDear.sqlite"), copyFromLegacy: false)
        try CopyMigration.copy(from: SwiftData.ModelContext(legacy), to: opened.container, addresses: addresses)
        let people = try opened.container.mainContext.fetch(HeldDear.FetchDescriptor<Person>())
        XCTAssertEqual(people.first { $0.id == fx.people[0] }?.mailingAddress?.zip, "62701")
        XCTAssertNil(people.first { $0.id == fx.people[1] }?.mailingAddress)
    }

    func testV3_aChangeTellsTheScreensThatReadIt() {
        let p = Person(name: "Ada")
        var fired = false
        withObservationTracking { _ = p.name } onChange: { fired = true }
        p.name = "Bea"
        XCTAssertTrue(fired)
        XCTAssertEqual(p.name, "Bea")
    }

    func testV3_linksAndListsSaveAndReadBack() throws {
        let opened = Store.open(inMemory: true)
        let context = opened.container.mainContext
        let person = Person(name: "Ada")
        let occasion = Occasion(type: .birthday, month: 5, day: 7)
        let act = Act(role: .plan, kind: .gift)
        act.ownerIDs = [person.id]
        context.insert(person)
        occasion.person = person   // joins the person's context
        let moment = Moment(year: 2027, dueDate: Date())
        moment.occasion = occasion
        act.moment = moment
        person.loves = ["tea", "maps"]
        try context.save()
        let again = HeldDear.ModelContext(opened.container)
        let p = try XCTUnwrap(again.fetch(HeldDear.FetchDescriptor<Person>()).first)
        XCTAssertEqual(p.loves, ["tea", "maps"])
        XCTAssertEqual(p.birthday?.month, 5)
        XCTAssertEqual(p.occasions.first?.moments.first?.acts.first?.ownerIDs, [p.id])
        // Deleting the person removes its days, moments and parts, as before.
        again.delete(p)
        try again.save()
        XCTAssertEqual(try again.fetchCount(HeldDear.FetchDescriptor<Act>()), 0)
        XCTAssertEqual(try again.fetchCount(HeldDear.FetchDescriptor<Occasion>()), 0)
    }

    // MARK: Fable S3: the copy, from a real version 2 store

    /// Writes a version 2 store (SwiftData, every version 2 field set) and returns the person, the part and their ids.
    private func writeV2Store(at url: URL) throws -> (person: UUID, act: UUID, owner: UUID) {
        let container = try SwiftData.ModelContainer(for: LegacyStore.schema, configurations: [LegacyStore.configuration(url: url)])
        let context = SwiftData.ModelContext(container)
        let ada = SchemaV2.Person(name: "Ada", fullName: "Ada Lee", contactID: "c-1", ring: .inner)
        ada.relationship = "sister"
        ada.loves = ["tea"]
        ada.showAgeOnCard = true
        let birthday = SchemaV2.Occasion(type: .birthday, month: 5, day: 7, birthYear: 1990)
        let moment = SchemaV2.Moment(year: 2027, dueDate: Date(timeIntervalSince1970: 1_810_000_000))
        moment.familyPageID = "page-9"
        let owner = UUID()
        let act = SchemaV2.Act(role: .plan, kind: .cake, title: "Lemon cake")
        act.label = "The cake"
        act.step = "ordered"
        act.ownerIDs = [owner]
        act.note = "Pick up at 3"
        act.sortOrder = 4
        let wish = SchemaV2.Wish(text: "Blue skates")
        let line = SchemaV2.LedgerEntry(year: 2026, type: .birthday, what: "A card", photoFile: nil, line: "Lovely",
                                         personName: "Ada", momentID: moment.id)
        context.insert(ada)
        context.insert(birthday); context.insert(moment); context.insert(act); context.insert(wish); context.insert(line)
        birthday.person = ada
        moment.occasion = birthday
        act.moment = moment
        wish.person = ada
        line.person = ada
        try context.save()
        return (ada.id, act.id, owner)
    }

    func testS3_aVersionTwoStoreCopiesEveryVersionTwoField() throws {
        let old = dir.appending(path: "default.store")
        let ids = try writeV2Store(at: old)
        let opened = Store.open(url: dir.appending(path: "HeldDear.sqlite"), legacyURL: old)
        XCTAssertEqual(opened.outcome, .opened)
        XCTAssertEqual(opened.copy, CopyMigration.Report(people: 1, occasions: 1, moments: 1, acts: 1, wishes: 1, ledger: 1))
        let c = HeldDear.ModelContext(opened.container)
        let ada = try XCTUnwrap(c.fetch(HeldDear.FetchDescriptor<Person>()).first)
        XCTAssertEqual(ada.id, ids.person)
        XCTAssertEqual(ada.relationship, "sister")
        XCTAssertEqual(ada.loves, ["tea"])
        XCTAssertTrue(ada.showAgeOnCard)
        XCTAssertEqual(ada.ring, .inner)
        XCTAssertEqual(ada.birthday?.birthYear, 1990)
        let act = try XCTUnwrap(c.fetch(HeldDear.FetchDescriptor<Act>()).first)
        XCTAssertEqual(act.id, ids.act)
        XCTAssertEqual(act.label, "The cake")
        XCTAssertEqual(act.step, "ordered")
        XCTAssertEqual(act.ownerIDs, [ids.owner])
        XCTAssertEqual(act.note, "Pick up at 3")
        XCTAssertEqual(act.sortOrder, 4)
        XCTAssertEqual(act.moment?.familyPageID, "page-9")
        XCTAssertEqual(act.moment?.occasion?.person?.id, ids.person)
        XCTAssertEqual(ada.wishes.first?.text, "Blue skates")
        XCTAssertEqual(ada.ledger.first?.line, "Lovely")
        XCTAssertTrue(CopyMigration.isCopied(opened.container.persistent), "Marked inside the store")
    }

    func testS3_aCopyKilledBeforeItsSaveRunsAgain() throws {
        // A kill before the one save leaves a version 3 file with no records and no mark.
        let old = dir.appending(path: "default.store")
        _ = try writeV2Store(at: old)
        let v3 = dir.appending(path: "HeldDear.sqlite")
        do { _ = Store.open(url: v3, copyFromLegacy: false) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: v3.path))
        XCTAssertFalse(CopyMigration.fileSaysCopied(v3))

        let opened = Store.open(url: v3, legacyURL: old)
        XCTAssertEqual(opened.outcome, .opened)
        XCTAssertEqual(opened.copy?.people, 1)
    }

    func testS3_aFailedCopyLeavesNothingAndIsTriedAgain() throws {
        struct Broken: Error {}
        let old = dir.appending(path: "default.store")
        _ = try writeV2Store(at: old)
        let before = try Data(contentsOf: old)
        let v3 = dir.appending(path: "HeldDear.sqlite")

        let failed = Store.open(url: v3, legacyURL: old, beforeCopySave: { _ in throw Broken() })
        XCTAssertEqual(failed.outcome, .inMemoryThisLaunch)
        XCTAssertEqual(failed.keptStoreURL, old)
        XCTAssertEqual(try Data(contentsOf: old), before, "The old store is untouched")
        XCTAssertFalse(CopyMigration.fileSaysCopied(v3))

        let retried = Store.open(url: v3, legacyURL: old)
        XCTAssertEqual(retried.outcome, .opened)
        XCTAssertEqual(retried.copy?.people, 1)
        XCTAssertEqual(try HeldDear.ModelContext(retried.container).fetchCount(HeldDear.FetchDescriptor<Person>()), 1, "Copied once, not twice")
    }

    func testS3_aCountMismatchStopsTheCopy() throws {
        let old = dir.appending(path: "default.store")
        _ = try writeV2Store(at: old)
        let v3 = dir.appending(path: "HeldDear.sqlite")
        let opened = Store.open(url: v3, legacyURL: old, beforeCopySave: { c in c.insert(Person(name: "Extra")) })
        XCTAssertEqual(opened.outcome, .inMemoryThisLaunch)
        XCTAssertFalse(CopyMigration.fileSaysCopied(v3))
        let reopened = Store.open(url: v3, legacyURL: old)
        XCTAssertEqual(try HeldDear.ModelContext(reopened.container).fetchCount(HeldDear.FetchDescriptor<Person>()), 1, "The extra record was never saved")
    }

    func testS2_aVersionThreeStoreWithRecordsIsNeverCopiedOver() throws {
        let old = dir.appending(path: "default.store")
        _ = try writeV2Store(at: old)
        let v3 = dir.appending(path: "HeldDear.sqlite")
        do {
            let s = Store.open(url: v3, copyFromLegacy: false)
            s.container.mainContext.insert(Person(name: "Bea"))
            try s.container.mainContext.save()
        }
        let opened = Store.open(url: v3, legacyURL: old)
        XCTAssertNil(opened.copy)
        let names = try HeldDear.ModelContext(opened.container).fetch(HeldDear.FetchDescriptor<Person>()).map(\.name)
        XCTAssertEqual(names, ["Bea"])
    }

    func testS3_readingADeletedRecordDoesNotCrash() throws {
        let opened = Store.open(inMemory: true)
        let c = opened.container.mainContext
        let p = Person(name: "Ada")
        c.insert(p)
        try c.save()
        c.delete(p)
        try c.save()
        // Reading a deleted, saved record answers without crashing (Fable S3).
        _ = p.name
        _ = p.id
        _ = p.occasions
        _ = p.mailingAddress
    }
}
