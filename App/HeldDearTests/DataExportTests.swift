import XCTest
import SwiftData
@testable import HeldDear

/// Item 3.0a: Export my data, the "couldn't be opened" screen, and the version 2 fixture.
/// The fixture is a version 2 store file written by `ExportFixture.write` from SchemaV2 in code, with invented names.
final class DataExportTests: XCTestCase {
    var dir: URL!
    var photos: URL!
    var storeURL: URL!
    let cal = Calendar(identifier: .gregorian)

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("ExportTests-\(UUID().uuidString)", isDirectory: true)
        photos = dir.appendingPathComponent("Photos", isDirectory: true)
        storeURL = dir.appendingPathComponent("default.store")
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: Fixture

    /// What the fixture holds. Three people, four occasions, four moments, six parts and greetings, three wishes,
    /// three yearly lines, six different image files (two of them named by more than one record).
    enum Expect {
        static let people = 3, occasions = 4, moments = 4, acts = 6, wishes = 3, ledger = 3
        static let photoFiles = ["robin-1.jpg", "robin-2.jpg", "jordan-1.jpg", "act-photo.jpg", "card-1.jpg", "wish-1.jpg"]
    }

    struct Ids {
        var robin = UUID(), casey = UUID(), robinMoment = UUID(), giftAct = UUID(), wish = UUID()
        var ledgerWithPhoto = UUID(), anniversary = UUID()
    }

    /// Writes the version 2 store at `url` and the image files into `photosDirectory`. Invented names only.
    @discardableResult
    func writeFixture(storeAt url: URL, photosIn photosDirectory: URL) throws -> Ids {
        var ids = Ids()
        let fixtureStore = Store.open(url: url, copyFromLegacy: false)
        let context = fixtureStore.container.mainContext
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d))! }

        let robin = Person(name: "Robin", fullName: "Robin Vale", contactID: "contact-robin", ring: .inner)
        robin.photoFiles = ["robin-1.jpg", "robin-2.jpg"]
        robin.relationship = "sister"
        robin.loves = ["kayaking", "tea"]
        let jordan = Person(name: "Jordan", ring: .outer)
        jordan.photoFiles = ["jordan-1.jpg"]
        jordan.manualPhone = "555-0100"
        let casey = Person(name: "Casey", ring: .inner)
        casey.relationship = "wife"
        casey.goodToKnow = "Calls on Sundays"
        casey.sizes = "M tops"
        for item in [robin, jordan, casey] { context.insert(item) }
        ids.robin = robin.id
        ids.casey = casey.id

        let robinBirthday = Occasion(type: .birthday, month: 3, day: 14, birthYear: 1980)
        let jordanBirthday = Occasion(type: .birthday, month: 7, day: 2)
        let caseyBirthday = Occasion(type: .birthday, month: 12, day: 17, birthYear: 1985)
        let anniversary = Occasion(type: .anniversary, month: 6, day: 5)
        anniversary.partnerName = "Alex"
        anniversary.extraRecipientIDs = [robin.id]
        for item in [robinBirthday, jordanBirthday, caseyBirthday, anniversary] { context.insert(item) }
        robinBirthday.person = robin
        jordanBirthday.person = jordan
        caseyBirthday.person = casey
        anniversary.person = casey

        let m1 = Moment(year: 2027, dueDate: date(2027, 3, 14))
        let m2 = Moment(year: 2027, dueDate: date(2027, 7, 2))
        let m3 = Moment(year: 2026, dueDate: date(2026, 12, 17))
        let m4 = Moment(year: 2027, dueDate: date(2027, 6, 5))
        m3.familyOwnerKey = "owner-key-should-not-be-exported"
        m3.familyPageID = "page-1"
        for item in [m1, m2, m3, m4] { context.insert(item) }
        m1.occasion = robinBirthday
        m2.occasion = jordanBirthday
        m3.occasion = caseyBirthday
        m4.occasion = anniversary
        ids.robinMoment = m1.id
        ids.anniversary = anniversary.id

        let wish = Wish(text: "Dry bag", url: "https://example.com/bag")
        let wish2 = Wish(text: "Tea sampler", imageFile: "wish-1.jpg")
        let wish3 = Wish(text: "Notebook")
        for item in [wish, wish2, wish3] { context.insert(item) }
        wish.person = robin
        wish2.person = robin
        wish3.person = jordan
        ids.wish = wish.id

        let gift = Act(role: .plan, kind: .gift, title: "Dry bag", wishID: wish.id)
        gift.step = "bought"
        gift.label = "From the shelf"
        gift.note = "Arrives Friday"
        gift.ownerIDs = [casey.id]
        gift.sortOrder = 2
        gift.photoFile = "act-photo.jpg"
        let card = Act(role: .plan, kind: .card)
        card.cardFile = "card-1.jpg"
        card.complete(.user)
        let cake = Act(role: .plan, kind: .cake)
        cake.step = "ordered"
        let day = Act(role: .plan, kind: .theDay)
        day.label = "Breakfast in bed"
        let greeting = Act(role: .greeting, kind: .message)
        greeting.complete(.messageSent)
        let call = Act(role: .plan, kind: .call)
        for item in [gift, card, cake, day, greeting, call] { context.insert(item) }
        gift.moment = m1
        card.moment = m1
        cake.moment = m3
        day.moment = m3
        greeting.moment = m2
        call.moment = m4
        ids.giftAct = gift.id

        let l1 = LedgerEntry(year: 2026, type: .birthday, what: "Tea sampler", photoFile: "robin-1.jpg", line: "Loved it",
                             personName: "Robin", momentID: m1.id)
        let l2 = LedgerEntry(year: 2025, type: .birthday, what: "A card", photoFile: nil, line: nil,
                             personName: "Robin", momentID: nil)
        l2.cardFile = "card-1.jpg"
        let l3 = LedgerEntry(year: 2025, type: .birthday, what: "A call", photoFile: nil, line: nil,
                             personName: "Jordan", momentID: nil)
        for item in [l1, l2, l3] { context.insert(item) }
        l1.person = robin
        l2.person = robin
        l3.person = jordan
        ids.ledgerWithPhoto = l1.id

        try context.save()

        for name in Expect.photoFiles {
            try Data("image bytes for \(name)".utf8).write(to: photosDirectory.appendingPathComponent(name))
        }
        return ids
    }

    /// The fixture, opened the way the app opens a store.
    func openFixture() throws -> (OpenedStore, Ids) {
        let ids = try writeFixture(storeAt: storeURL, photosIn: photos)
        let opened = Store.open(url: storeURL)
        XCTAssertEqual(opened.outcome, .opened)
        return (opened, ids)
    }

    func testFixture_isAVersion2StoreWithKnownCounts() throws {
        let (opened, _) = try openFixture()
        let c = HeldDear.ModelContext(opened.container)
        XCTAssertEqual(try c.fetchCount(HeldDear.FetchDescriptor<Person>()), Expect.people)
        XCTAssertEqual(try c.fetchCount(HeldDear.FetchDescriptor<Occasion>()), Expect.occasions)
        XCTAssertEqual(try c.fetchCount(HeldDear.FetchDescriptor<Moment>()), Expect.moments)
        XCTAssertEqual(try c.fetchCount(HeldDear.FetchDescriptor<Act>()), Expect.acts)
        XCTAssertEqual(try c.fetchCount(HeldDear.FetchDescriptor<Wish>()), Expect.wishes)
        XCTAssertEqual(try c.fetchCount(HeldDear.FetchDescriptor<LedgerEntry>()), Expect.ledger)
        XCTAssertEqual(SchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
    }

    // MARK: Export

    func exportFolder() -> URL { dir.appendingPathComponent("out", isDirectory: true) }

    func testExport_countsMatchTheFixture() throws {
        let (opened, _) = try openFixture()
        let summary = try DataExport.write(context: HeldDear.ModelContext(opened.container), photosDirectory: photos, to: exportFolder())
        XCTAssertEqual(summary, DataExport.Summary(people: Expect.people, occasions: Expect.occasions, moments: Expect.moments,
                                                   acts: Expect.acts, wishes: Expect.wishes, ledger: Expect.ledger,
                                                   photos: Expect.photoFiles.count, missingPhotos: []))
        let doc = try DataExport.read(folder: exportFolder())
        XCTAssertEqual(doc.people.count, Expect.people)
        XCTAssertEqual(doc.occasions.count, Expect.occasions)
        XCTAssertEqual(doc.moments.count, Expect.moments)
        XCTAssertEqual(doc.acts.count, Expect.acts)
        XCTAssertEqual(doc.wishes.count, Expect.wishes)
        XCTAssertEqual(doc.ledger.count, Expect.ledger)
        XCTAssertEqual(doc.counts, DataExport.Counts(people: 3, occasions: 4, moments: 4, acts: 6, wishes: 3, ledger: 3, photos: 6))
        XCTAssertEqual(doc.storeVersion, "2.0.0")
        XCTAssertEqual(Set(doc.people.map(\.name)), ["Robin", "Jordan", "Casey"])
    }

    func testExport_containsEveryPhotoWithTheSameBytes() throws {
        let (opened, _) = try openFixture()
        try DataExport.write(context: HeldDear.ModelContext(opened.container), photosDirectory: photos, to: exportFolder())
        let inFolder = try FileManager.default.contentsOfDirectory(atPath: exportFolder().appendingPathComponent("photos").path)
        XCTAssertEqual(Set(inFolder), Set(Expect.photoFiles))
        for name in Expect.photoFiles {
            let copied = try Data(contentsOf: exportFolder().appendingPathComponent("photos").appendingPathComponent(name))
            XCTAssertEqual(copied, try Data(contentsOf: photos.appendingPathComponent(name)), name)
        }
        // Every image any record names is there, whichever record names it.
        let doc = try DataExport.read(folder: exportFolder())
        for name in DataExport.photoFileNames(doc) {
            XCTAssertTrue(FileManager.default.fileExists(atPath: exportFolder().appendingPathComponent("photos/\(name)").path), name)
        }
    }

    func testExport_keepsEveryStoredFieldAndLink() throws {
        let (opened, ids) = try openFixture()
        try DataExport.write(context: HeldDear.ModelContext(opened.container), photosDirectory: photos, to: exportFolder())
        let doc = try DataExport.read(folder: exportFolder())
        let gift = try XCTUnwrap(doc.acts.first { $0.id == ids.giftAct })
        XCTAssertEqual(gift.step, "bought")
        XCTAssertEqual(gift.label, "From the shelf")
        XCTAssertEqual(gift.note, "Arrives Friday")
        XCTAssertEqual(gift.ownerIDs, [ids.casey])
        XCTAssertEqual(gift.sortOrder, 2)
        XCTAssertEqual(gift.wishID, ids.wish)
        XCTAssertEqual(gift.momentID, ids.robinMoment)
        XCTAssertEqual(gift.photoFile, "act-photo.jpg")
        let robin = try XCTUnwrap(doc.people.first { $0.id == ids.robin })
        XCTAssertEqual(robin.relationship, "sister")
        XCTAssertEqual(robin.loves, ["kayaking", "tea"])
        XCTAssertEqual(robin.photoFiles, ["robin-1.jpg", "robin-2.jpg"])
        XCTAssertEqual(robin.ring, "inner")
        XCTAssertEqual(doc.wishes.first { $0.id == ids.wish }?.personID, ids.robin)
        XCTAssertEqual(doc.ledger.first { $0.id == ids.ledgerWithPhoto }?.personID, ids.robin)
        XCTAssertEqual(doc.occasions.first { $0.id == ids.anniversary }?.personID, ids.casey)
        XCTAssertEqual(doc.occasions.first { $0.id == ids.anniversary }?.extraRecipientIDs, [ids.robin])
        XCTAssertEqual(doc.occasions.first { $0.id == ids.anniversary }?.partnerName, "Alex")
        XCTAssertEqual(doc.moments.first { $0.id == ids.robinMoment }?.occasionID != nil, true)
    }

    func testExport_leavesTheFamilyPageOwnerKeyOut() throws {
        let (opened, _) = try openFixture()
        try DataExport.write(context: HeldDear.ModelContext(opened.container), photosDirectory: photos, to: exportFolder())
        let text = try String(contentsOf: exportFolder().appendingPathComponent(DataExport.jsonName), encoding: .utf8)
        XCTAssertFalse(text.contains("owner-key-should-not-be-exported"))
        XCTAssertTrue(text.contains("page-1"))
    }

    func testExport_aMissingImageIsListedAndTheRestIsStillWritten() throws {
        let (opened, _) = try openFixture()
        try FileManager.default.removeItem(at: photos.appendingPathComponent("jordan-1.jpg"))
        let summary = try DataExport.write(context: HeldDear.ModelContext(opened.container), photosDirectory: photos, to: exportFolder())
        XCTAssertEqual(summary.missingPhotos, ["jordan-1.jpg"])
        XCTAssertEqual(summary.photos, Expect.photoFiles.count - 1)
        XCTAssertEqual(summary.people, Expect.people)
        XCTAssertEqual(try DataExport.read(folder: exportFolder()).missingPhotos, ["jordan-1.jpg"])
    }

    func testExport_readsOnlyAndChangesNothing() throws {
        let (opened, _) = try openFixture()
        let context = HeldDear.ModelContext(opened.container)
        try DataExport.write(context: context, photosDirectory: photos, to: exportFolder())
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(try context.fetchCount(HeldDear.FetchDescriptor<Act>()), Expect.acts)
        for name in Expect.photoFiles { XCTAssertTrue(FileManager.default.fileExists(atPath: photos.appendingPathComponent(name).path)) }
    }

    func testExport_makesOneZipForTheShareSheet() throws {
        let (opened, _) = try openFixture()
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 12))!
        let result = try DataExport.exportForSharing(context: HeldDear.ModelContext(opened.container), photosDirectory: photos,
                                                     in: dir, now: now)
        XCTAssertEqual(result.zip.lastPathComponent, "HeldDear-data-2026-11-21.zip")
        let bytes = try Data(contentsOf: result.zip)
        XCTAssertGreaterThan(bytes.count, 100)
        XCTAssertEqual(Array(bytes.prefix(2)), [0x50, 0x4B], "A zip file starts with PK")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("HeldDear-data-2026-11-21").path),
                       "The loose folder is removed")
        XCTAssertEqual(result.summary.people, Expect.people)
    }

    // MARK: Store set aside

    func testSetAside_anUnreadableStoreIsKeptAsideAndTheScreenShows() throws {
        let junk = Data("This is not a Held Dear store.".utf8)
        try junk.write(to: storeURL)
        let opened = Store.open(url: dir.appending(path: "HeldDear.sqlite"), legacyURL: storeURL)
        XCTAssertEqual(opened.outcome, .freshStoreOldKeptAside)
        let kept = try XCTUnwrap(opened.keptStoreURL)
        XCTAssertEqual(try Data(contentsOf: kept), junk, "Kept, untouched, not deleted")

        XCTAssertTrue(StoreSetAside.shouldShow(outcome: opened.outcome, acknowledged: false))
        XCTAssertFalse(StoreSetAside.shouldShow(outcome: opened.outcome, acknowledged: true), "Continue closes it")
        XCTAssertTrue(StoreSetAside.shouldShow(outcome: .inMemoryThisLaunch, acknowledged: false))
        XCTAssertFalse(StoreSetAside.shouldShow(outcome: .opened, acknowledged: false), "A store that opens shows nothing")
    }

    func testSetAside_theScreenWords() {
        XCTAssertEqual(StoreSetAside.message, "Your saved plans couldn't be opened. They're kept safe on this iPhone.")
        XCTAssertEqual(StoreSetAside.exportTitle, "Export them")
        XCTAssertEqual(StoreSetAside.continueTitle, "Continue")
    }

    func testSetAside_exportThemSharesTheKeptFileAsItIs() throws {
        let junk = Data("This is not a Held Dear store.".utf8)
        try junk.write(to: storeURL)
        try Data("wal".utf8).write(to: URL(fileURLWithPath: storeURL.path + "-wal"))
        try Data("photo".utf8).write(to: photos.appendingPathComponent("robin-1.jpg"))
        let opened = Store.open(url: dir.appending(path: "HeldDear.sqlite"), legacyURL: storeURL)
        let kept = try XCTUnwrap(opened.keptStoreURL)

        let source = try XCTUnwrap(StoreSetAside.storeToExport(kept: kept, original: storeURL))
        XCTAssertEqual(source, kept)
        let staged = try DataExport.stageKeptStore(storeURL: source, photosDirectory: photos, in: dir)
        XCTAssertEqual(try Data(contentsOf: staged.appendingPathComponent(kept.lastPathComponent)), junk)
        XCTAssertEqual(try Data(contentsOf: staged.appendingPathComponent(kept.lastPathComponent + "-wal")), Data("wal".utf8))
        XCTAssertEqual(try Data(contentsOf: staged.appendingPathComponent("photos/robin-1.jpg")), Data("photo".utf8))
        XCTAssertEqual(try Data(contentsOf: kept), junk, "Staging copies; the kept file stays where it was")

        let zipped = try DataExport.keptStoreBundle(storeURL: source, photosDirectory: photos, in: dir)
        XCTAssertEqual(Array(try Data(contentsOf: zipped).prefix(2)), [0x50, 0x4B])
    }

    func testSetAside_whereTheSavedPlansAre() throws {
        let original = dir.appendingPathComponent("original.store")
        let kept = dir.appendingPathComponent("kept.store")
        XCTAssertNil(StoreSetAside.storeToExport(kept: kept, original: original), "Nothing there")
        try Data("a".utf8).write(to: original)
        XCTAssertEqual(StoreSetAside.storeToExport(kept: nil, original: original), original, "Not moved aside: use the original")
        try Data("b".utf8).write(to: kept)
        XCTAssertEqual(StoreSetAside.storeToExport(kept: kept, original: original), kept)
    }
}
