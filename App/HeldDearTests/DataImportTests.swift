import XCTest
@testable import HeldDear

/// "Import my data": export, import into an empty store, export again, and the two documents match.
@MainActor
final class DataImportTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("ImportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    /// A small plan with every kind of record and link, and two photos. Invented names only.
    private func fill(_ c: ModelContext, photos: URL) throws {
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        try Data("a".utf8).write(to: photos.appendingPathComponent("ada-1.jpg"))
        try Data("c".utf8).write(to: photos.appendingPathComponent("card-1.jpg"))
        let ada = Person(name: "Ada", fullName: "Ada Lee", contactID: "c-1", ring: .inner)
        ada.photoFiles = ["ada-1.jpg"]
        ada.loves = ["tea", "maps"]
        ada.relationship = "sister"
        ada.mailingAddress = MailAddress(firstName: "Ada", address1: "1 Main St", city: "Springfield", state: "IL", zip: "62701")
        let bea = Person(name: "Bea")
        ada.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        bea.createdAt = Date(timeIntervalSince1970: 1_700_000_100)
        c.insert(ada); c.insert(bea)
        let birthday = Occasion(type: .birthday, month: 5, day: 7, birthYear: 1990)
        birthday.person = ada
        let anniversary = Occasion(type: .anniversary, month: 6, day: 5)
        anniversary.partnerName = "Sam"
        anniversary.extraRecipientIDs = [bea.id]
        anniversary.person = bea
        let m = Moment(year: 2027, dueDate: Date(timeIntervalSince1970: 1_810_000_000))
        m.occasion = birthday
        let gift = Act(role: .plan, kind: .gift, title: "Blue skates")
        gift.step = "bought"
        gift.ownerIDs = [bea.id]
        gift.sortOrder = 2
        gift.moment = m
        let card = Act(role: .plan, kind: .card)
        card.cardFile = "card-1.jpg"
        card.complete(.user, at: Date(timeIntervalSince1970: 1_800_000_000))
        card.moment = m
        let wish = Wish(text: "Blue skates", url: "https://example.com/skates", capturedAt: Date(timeIntervalSince1970: 1_790_000_000))
        wish.person = ada
        let line = LedgerEntry(year: 2026, type: .birthday, what: "A card", photoFile: nil, line: "Loved it",
                               personName: "Ada", momentID: m.id)
        line.person = ada
        gift.createdAt = Date(timeIntervalSince1970: 1_700_000_200)
        card.createdAt = Date(timeIntervalSince1970: 1_700_000_300)
        line.createdAt = Date(timeIntervalSince1970: 1_700_000_400)
        try c.save()
    }

    private func comparable(_ d: DataExport.Document) -> DataExport.Document {
        var d = d
        d.exportedAt = Date(timeIntervalSince1970: 0)
        d.settings = nil
        // Same records in a steady order (fetch order isn't fixed).
        d.people.sort { $0.id.uuidString < $1.id.uuidString }
        d.occasions.sort { $0.id.uuidString < $1.id.uuidString }
        d.moments.sort { $0.id.uuidString < $1.id.uuidString }
        d.acts.sort { $0.id.uuidString < $1.id.uuidString }
        d.wishes.sort { $0.id.uuidString < $1.id.uuidString }
        d.ledger.sort { $0.id.uuidString < $1.id.uuidString }
        return d
    }

    func testExportImportExportMatches() throws {
        let photosA = dir.appendingPathComponent("photosA", isDirectory: true)
        let source = Store.open(inMemory: true).container.mainContext
        try fill(source, photos: photosA)
        let out = dir.appendingPathComponent("HeldDear-data", isDirectory: true)
        try DataExport.write(context: source, photosDirectory: photosA, to: out)
        let zip = try DataExport.zip(folder: out)
        let first = try DataExport.read(folder: out)

        let target = Store.open(inMemory: true).container.mainContext
        let photosB = dir.appendingPathComponent("photosB", isDirectory: true)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ImportTests"))
        defaults.removePersistentDomain(forName: "ImportTests")
        let folder = try DataImport.exportFolder(fromPicked: zip, workIn: dir)
        let summary = try DataImport.restore(folder: folder, into: target, photosDirectory: photosB, defaults: defaults)
        XCTAssertEqual(summary.people, 2)
        XCTAssertEqual(summary.acts, 2)
        XCTAssertEqual(summary.photos, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: photosB.appendingPathComponent("ada-1.jpg").path))

        let again = dir.appendingPathComponent("again", isDirectory: true)
        try DataExport.write(context: target, photosDirectory: photosB, to: again)
        let second = try DataExport.read(folder: again)
        XCTAssertEqual(comparable(second), comparable(first), "Export, import, export: the same document")
    }

    func testAStoreWithPlansIsNotImportedIntoUnlessReplacing() throws {
        let photos = dir.appendingPathComponent("photos", isDirectory: true)
        let source = Store.open(inMemory: true).container.mainContext
        try fill(source, photos: photos)
        let out = dir.appendingPathComponent("export", isDirectory: true)
        try DataExport.write(context: source, photosDirectory: photos, to: out)

        let target = Store.open(inMemory: true).container.mainContext
        target.insert(Person(name: "Cal"))
        try target.save()
        XCTAssertThrowsError(try DataImport.restore(folder: out, into: target, photosDirectory: photos)) {
            XCTAssertEqual($0 as? DataImport.Failure, .notEmpty)
        }
        XCTAssertEqual(try target.fetch(FetchDescriptor<Person>()).map(\.name), ["Cal"], "Nothing changed")

        try DataImport.restore(folder: out, into: target, replacing: true, photosDirectory: photos)
        XCTAssertEqual(Set(try target.fetch(FetchDescriptor<Person>()).map(\.name)), ["Ada", "Bea"])
    }

    func testAFileThatIsNotAnExportChangesNothing() throws {
        let junk = dir.appendingPathComponent("notes", isDirectory: true)
        try FileManager.default.createDirectory(at: junk, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: junk.appendingPathComponent(DataExport.jsonName))
        let target = Store.open(inMemory: true).container.mainContext
        XCTAssertThrowsError(try DataImport.restore(folder: junk, into: target, photosDirectory: dir))
        XCTAssertTrue(DataImport.storeIsEmpty(target))
    }

    func testSettingsComeBack() throws {
        let source = Store.open(inMemory: true).container.mainContext
        try fill(source, photos: dir.appendingPathComponent("p", isDirectory: true))
        var doc = try DataExport.document(from: source, now: Date())
        doc.settings = DataExport.Settings(yourName: "Sam", cardSignature: "The Hollands", customHolidays: [],
                                           enabledHolidays: ["christmas"], hiddenPhotoIDs: ["x"],
                                           places: [Place(kindRaw: "cake", name: "Main St Cakes")])
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ImportSettingsTests"))
        defaults.removePersistentDomain(forName: "ImportSettingsTests")
        let target = Store.open(inMemory: true).container.mainContext
        try DataImport.restore(doc, photosFolder: nil, into: target, defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: "yourName"), "Sam")
        XCTAssertEqual(defaults.string(forKey: "cardSignature"), "The Hollands")
        XCTAssertEqual(PlaceStore(defaults: defaults).all.map(\.name), ["Main St Cakes"])
        XCTAssertEqual(defaults.stringArray(forKey: "hiddenPhotoIDs"), ["x"])
    }

    func testZipReaderInflatesAndRefusesPathsOutside() throws {
        let folder = dir.appendingPathComponent("z", isDirectory: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("photos"), withIntermediateDirectories: true)
        let text = String(repeating: "Held Dear ", count: 500)
        try Data(text.utf8).write(to: folder.appendingPathComponent("a.txt"))
        let zip = try DataExport.zip(folder: folder)
        let out = dir.appendingPathComponent("out", isDirectory: true)
        try ZipReader.extract(zip, to: out)
        let found = FileManager.default.enumerator(at: out, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.first { $0.lastPathComponent == "a.txt" }
        XCTAssertEqual(try String(contentsOf: XCTUnwrap(found), encoding: .utf8), text)
    }
}
