import XCTest
import CoreData
@testable import HeldDear

/// Item 3.1: the 3.1 model, moving a 3.0 store to it, duplicate rules (Fable C4) and settings sync (C5).
@MainActor
final class ICloudSyncTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("SyncTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func testModel31AddsPhotoAndEncryptsFreeText() {
        let m = CoreStore.model
        XCTAssertNotNil(m.entitiesByName["Photo"]?.attributesByName["data"])
        XCTAssertTrue(m.entitiesByName["Photo"]?.attributesByName["data"]?.allowsExternalBinaryDataStorage == true)
        XCTAssertTrue(m.entitiesByName["Person"]?.attributesByName["goodToKnow"]?.allowsCloudEncryption == true)
        XCTAssertTrue(m.entitiesByName["Act"]?.attributesByName["note"]?.allowsCloudEncryption == true)
        XCTAssertFalse(m.entitiesByName["Person"]?.attributesByName["id"]?.allowsCloudEncryption == true)
        XCTAssertNil(CoreStore.modelV30.entitiesByName["Photo"], "3.0 stays as build 1030 shipped it")
        // Every 3.0 field is still in 3.1 with the same type.
        for e in CoreStore.modelV30.entities {
            for (name, a) in e.attributesByName {
                XCTAssertEqual(m.entitiesByName[e.name!]?.attributesByName[name]?.attributeType, a.attributeType, "\(e.name!).\(name)")
            }
        }
    }

    func testA30StoreMovesTo31AndKeepsEverything() throws {
        let url = dir.appendingPathComponent("HeldDear.sqlite")
        // A store as build 1030 wrote it.
        do {
            let old = NSPersistentContainer(name: "HeldDear", managedObjectModel: CoreStore.modelV30)
            let d = NSPersistentStoreDescription(url: url)
            d.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            old.persistentStoreDescriptions = [d]
            var failure: Error?
            old.loadPersistentStores { _, e in failure = e }
            XCTAssertNil(failure)
            let ctx = old.viewContext
            let p = NSEntityDescription.insertNewObject(forEntityName: "Person", into: ctx)
            p.setValue(UUID(), forKey: "id")
            p.setValue("Ada", forKey: "name")
            p.setValue("Calls on Sundays", forKey: "goodToKnow")
            let o = NSEntityDescription.insertNewObject(forEntityName: "Occasion", into: ctx)
            o.setValue(UUID(), forKey: "id")
            o.setValue(5, forKey: "month")
            o.setValue(p, forKey: "person")
            try ctx.save()
            for store in old.persistentStoreCoordinator.persistentStores { try old.persistentStoreCoordinator.remove(store) }
        }

        let opened = Store.open(url: url, copyFromLegacy: false)
        XCTAssertEqual(opened.outcome, .opened)
        let people = try HeldDear.ModelContext(opened.container).fetch(HeldDear.FetchDescriptor<Person>())
        XCTAssertEqual(people.map(\.name), ["Ada"])
        XCTAssertEqual(people.first?.goodToKnow, "Calls on Sundays")
        XCTAssertEqual(people.first?.birthday?.month, 5)
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix("HeldDear-before-3.1-") && $0.hasSuffix(".sqlite") }
        XCTAssertEqual(backups.count, 1, "A copy of the 3.0 store is kept")
    }

    func testDuplicatePeopleFromTheSameContactFold() throws {
        let c = Store.open(inMemory: true).container.mainContext
        let a = Person(name: "Ada", contactID: "c-1")
        a.createdAt = Date(timeIntervalSince1970: 100)
        let b = Person(name: "Ada", contactID: "c-1")
        b.createdAt = Date(timeIntervalSince1970: 200)
        c.insert(a); c.insert(b)
        let w = Wish(text: "Skates")
        w.person = b
        let o1 = Occasion(type: .birthday, month: 5, day: 7)
        o1.person = a
        let o2 = Occasion(type: .birthday, month: 5, day: 7)
        o2.person = b
        let m1 = Moment(year: 2027, dueDate: Date())
        m1.occasion = o1
        let m2 = Moment(year: 2027, dueDate: Date())
        m2.occasion = o2
        let act = Act(role: .plan, kind: .cake)
        act.moment = m2
        try c.save()

        XCTAssertEqual(Duplicates.tidy(c), 3, "One person, one day and one year folded")
        try c.save()
        let people = try c.fetch(FetchDescriptor<Person>())
        XCTAssertEqual(people.count, 1)
        XCTAssertEqual(people[0].id, a.id, "The oldest is kept")
        XCTAssertEqual(people[0].wishes.map(\.text), ["Skates"])
        XCTAssertEqual(people[0].occasions.count, 1)
        XCTAssertEqual(people[0].occasions.first?.moments.first?.acts.count, 1, "The part moved, not lost")
        XCTAssertEqual(Duplicates.tidy(c), 0, "A second pass changes nothing")
    }

    func testAYearlyLineWrittenTwiceIsKeptOnce() throws {
        let c = Store.open(inMemory: true).container.mainContext
        let p = Person(name: "Ada")
        c.insert(p)
        let moment = UUID()
        for i in 0..<2 {
            let l = LedgerEntry(year: 2026, type: .birthday, what: "A card", photoFile: nil, line: nil, personName: "Ada", momentID: moment)
            l.createdAt = Date(timeIntervalSince1970: Double(i))
            l.person = p
        }
        let other = LedgerEntry(year: 2025, type: .birthday, what: "A call", photoFile: nil, line: nil, personName: "Ada", momentID: nil)
        other.person = p
        try c.save()
        XCTAssertEqual(Duplicates.tidy(c), 1)
        try c.save()
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<LedgerEntry>()), 2)
    }

    func testSettingsPullOnlyFillsWhatIsMissingAtFirst() throws {
        let local = try XCTUnwrap(UserDefaults(suiteName: "SyncSettingsTests"))
        local.removePersistentDomain(forName: "SyncSettingsTests")
        local.set("Here", forKey: "yourName")
        let cloud: [String: Any] = ["yourName": "There", "cardSignature": "The Hollands"]
        ICloudSync.Settings.pull(local: local, cloudValue: { cloud[$0] }, onlyMissing: true)
        XCTAssertEqual(local.string(forKey: "yourName"), "Here")
        XCTAssertEqual(local.string(forKey: "cardSignature"), "The Hollands")
        ICloudSync.Settings.pull(local: local, cloudValue: { cloud[$0] }, onlyMissing: false)
        XCTAssertEqual(local.string(forKey: "yourName"), "There", "A change from another device comes in")
    }
}
