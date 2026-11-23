import XCTest
import CoreData
@testable import HeldDear

/// The CloudKit schema file is generated from `CoreStore.model` (CloudKitSchema), never written by hand. These tests
/// check the mapping rules against the model itself: nothing is added to a field line that the model doesn't have.
final class CloudKitSchemaTests: XCTestCase {
    private let model = CoreStore.model

    private func lines(of entity: NSEntityDescription, in text: String) -> [String] {
        let start = text.range(of: "RECORD TYPE CD_\(entity.name!) (")!
        let rest = text[start.upperBound...]
        let end = rest.range(of: ");")!
        return rest[..<end.lowerBound].split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    func testEveryAttributeAndToOneLinkHasExactlyOneLine() {
        let text = CloudKitSchema.ckdb(for: model)
        for entity in model.entities {
            let body = lines(of: entity, in: text)
            for (name, a) in entity.attributesByName {
                for field in CloudKitSchema.fields(for: a).map(\.name) {
                    XCTAssertEqual(body.filter { $0.hasPrefix("\"\(field)\" ") }.count, 1, "\(entity.name!).\(name) -> \(field)")
                }
            }
            for (name, r) in entity.relationshipsByName {
                let count = body.filter { $0.hasPrefix("\"CD_\(name)\" ") }.count
                XCTAssertEqual(count, r.isToMany ? 0 : 1, "\(entity.name!).\(name): a to-one link has one line, a to-many none")
            }
        }
    }

    func testEveryRecordTypeIsOneEntityWithTheTwoIndexes() {
        let text = CloudKitSchema.ckdb(for: model)
        XCTAssertEqual(text.components(separatedBy: "RECORD TYPE ").count - 1, model.entities.count)
        for entity in model.entities {
            let body = lines(of: entity, in: text)
            XCTAssertTrue(body.contains("\"___recordID\" REFERENCE QUERYABLE,"), "\(entity.name!) has recordName QUERYABLE")
            XCTAssertTrue(body.contains("\"CD_entityName\" STRING QUERYABLE,"), "\(entity.name!) has CD_entityName QUERYABLE")
        }
    }

    func testTypesFollowTheMapping() {
        let text = CloudKitSchema.ckdb(for: model)
        let person = lines(of: model.entitiesByName["Person"]!, in: text)
        XCTAssertTrue(person.contains("\"CD_id\" STRING,"), "a UUID is a STRING")
        XCTAssertTrue(person.contains("\"CD_createdAt\" TIMESTAMP,"))
        XCTAssertTrue(person.contains("\"CD_showAgeOnCard\" INT64,"), "a boolean is INT64")
        XCTAssertTrue(person.contains("\"CD_name\" ENCRYPTED STRING,"), "free text is encrypted in iCloud")
        XCTAssertTrue(person.contains("\"CD_ringRaw\" STRING,"))
        let occasion = lines(of: model.entitiesByName["Occasion"]!, in: text)
        XCTAssertTrue(occasion.contains("\"CD_month\" ENCRYPTED INT64,"), "an encrypted integer")
        XCTAssertTrue(occasion.contains("\"CD_typeRaw\" STRING,"))
        XCTAssertTrue(occasion.contains("\"CD_typeRaw_ckAsset\" ASSET,"), "every String has its asset companion")
        XCTAssertTrue(occasion.contains("\"CD_person\" STRING,"), "a to-one link is a STRING record name")
        let photo = lines(of: model.entitiesByName["Photo"]!, in: text)
        XCTAssertTrue(photo.contains("\"CD_data\" BYTES,"), "a large binary keeps its bytes field")
        XCTAssertTrue(photo.contains("\"CD_data_ckAsset\" ASSET,"), "and has its asset field")
        // Every attribute kept outside the database gets both fields, in every record type.
        for entity in model.entities {
            for (_, a) in entity.attributesByName where a.allowsExternalBinaryDataStorage {
                let body = lines(of: entity, in: text)
                XCTAssertTrue(body.contains("\"CD_\(a.name)\" BYTES,"), "\(entity.name!).\(a.name)")
                XCTAssertTrue(body.contains("\"CD_\(a.name)_ckAsset\" ASSET,"), "\(entity.name!).\(a.name)")
            }
        }
    }

    func testEncryptedFieldsAreExactlyTheModelsEncryptedAttributes() {
        let text = CloudKitSchema.ckdb(for: model)
        for entity in model.entities {
            let body = lines(of: entity, in: text)
            for (_, a) in entity.attributesByName where a.attributeType != .binaryDataAttributeType {
                let field = CloudKitSchema.field(for: a).name
                let line = body.first { $0.hasPrefix("\"\(field)\" ") } ?? ""
                XCTAssertEqual(line.contains(" ENCRYPTED "), a.allowsCloudEncryption, "\(entity.name!).\(a.name)")
            }
        }
    }

    func testTheFamilyPageFieldsAreEncryptedInICloud() {
        let moment = lines(of: model.entitiesByName["Moment"]!, in: CloudKitSchema.ckdb(for: model))
        for name in ["familyOwnerKey", "familyInviteURL", "familyGiftURL"] {
            XCTAssertTrue(model.entitiesByName["Moment"]?.attributesByName[name]?.allowsCloudEncryption == true, name)
            XCTAssertTrue(moment.contains("\"CD_\(name)\" ENCRYPTED STRING,"), name)
        }
    }

    /// Fable's schema review (P4, P5): a field can be encrypted only before its schema is deployed.
    func testTheBirthDateParts_FamilyPageIDAndContactIDAreEncryptedInICloud() {
        let text = CloudKitSchema.ckdb(for: model)
        let occasion = lines(of: model.entitiesByName["Occasion"]!, in: text)
        for field in ["CD_birthYear", "CD_month", "CD_day"] {
            XCTAssertTrue(occasion.contains("\"\(field)\" ENCRYPTED INT64,"), field)
        }
        XCTAssertTrue(lines(of: model.entitiesByName["Moment"]!, in: text).contains("\"CD_familyPageID\" ENCRYPTED STRING,"))
        XCTAssertTrue(lines(of: model.entitiesByName["Person"]!, in: text).contains("\"CD_contactID\" ENCRYPTED STRING,"))
    }

    /// Fable's schema review (P2): Core Data pairs every String attribute and every binary attribute with an asset field;
    /// no other type gets one. A missing field makes the server reject the record in Production.
    func testEveryStringAndBinaryAttributeHasOneAssetCompanionAndNothingElseDoes() {
        let text = CloudKitSchema.ckdb(for: model)
        for entity in model.entities {
            let body = lines(of: entity, in: text)
            for (name, a) in entity.attributesByName {
                let asset = body.filter { $0.hasPrefix("\"CD_\(name)_ckAsset\" ") }
                let expected = a.attributeType == .stringAttributeType || a.attributeType == .binaryDataAttributeType
                XCTAssertEqual(asset.count, expected ? 1 : 0, "\(entity.name!).\(name)")
                if expected { XCTAssertEqual(asset.first, "\"CD_\(name)_ckAsset\" ASSET,") }
            }
            let assetLines = body.filter { $0.contains("_ckAsset") }.count
            let expectedCount = entity.attributesByName.values.filter {
                $0.attributeType == .stringAttributeType || $0.attributeType == .binaryDataAttributeType
            }.count
            XCTAssertEqual(assetLines, expectedCount, "\(entity.name!): no asset line without an attribute")
        }
    }

    /// A store written by the 3.2 model as it was before the family-page fields were encrypted (the same model with
    /// that flag off) opens with the new model as it is: no upgrade step, nothing kept aside, the value intact.
    func testAStoreFromBeforeTheChangeOpensWithTheNewModelWithoutAnUpgrade() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("FamilyFields-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("HeldDear.sqlite")

        let before = model.copy() as! NSManagedObjectModel
        for (entity, name) in [("Moment", "familyOwnerKey"), ("Moment", "familyInviteURL"), ("Moment", "familyGiftURL"),
                               ("Moment", "familyPageID"), ("Occasion", "birthYear"), ("Occasion", "month"),
                               ("Occasion", "day"), ("Person", "contactID")] {
            before.entitiesByName[entity]!.attributesByName[name]!.allowsCloudEncryption = false
        }
        XCTAssertEqual(before.entityVersionHashesByName, model.entityVersionHashesByName,
                       "the encryption flag does not change the model's version, so no upgrade step is needed")

        do {
            let old = NSPersistentContainer(name: "HeldDear", managedObjectModel: before)
            let d = NSPersistentStoreDescription(url: url)
            d.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            old.persistentStoreDescriptions = [d]
            var failure: Error?
            old.loadPersistentStores { _, e in failure = e }
            XCTAssertNil(failure)
            let person = NSEntityDescription.insertNewObject(forEntityName: "Person", into: old.viewContext)
            person.setValue(UUID(), forKey: "id")
            person.setValue("contact-1", forKey: "contactID")
            let occasion = NSEntityDescription.insertNewObject(forEntityName: "Occasion", into: old.viewContext)
            occasion.setValue(UUID(), forKey: "id")
            occasion.setValue(3, forKey: "month")
            occasion.setValue(9, forKey: "day")
            occasion.setValue(1990, forKey: "birthYear")
            occasion.setValue(person, forKey: "person")
            let m = NSEntityDescription.insertNewObject(forEntityName: "Moment", into: old.viewContext)
            m.setValue(UUID(), forKey: "id")
            m.setValue("page-1", forKey: "familyPageID")
            m.setValue("owner-key-1", forKey: "familyOwnerKey")
            m.setValue("https://example.invalid/invite", forKey: "familyInviteURL")
            try old.viewContext.save()
            for store in old.persistentStoreCoordinator.persistentStores { try old.persistentStoreCoordinator.remove(store) }
        }

        let opened = Store.open(url: url, copyFromLegacy: false)
        XCTAssertEqual(opened.outcome, .opened)
        XCTAssertNil(opened.keptStoreURL, "nothing was kept aside")
        let moments = try HeldDear.ModelContext(opened.container).fetch(HeldDear.FetchDescriptor<Moment>())
        XCTAssertEqual(moments.count, 1)
        XCTAssertEqual(moments.first?.familyOwnerKey, "owner-key-1")
        XCTAssertEqual(moments.first?.familyInviteURL, "https://example.invalid/invite")
        XCTAssertEqual(moments.first?.familyPageID, "page-1")
        let occasions = try HeldDear.ModelContext(opened.container).fetch(HeldDear.FetchDescriptor<Occasion>())
        XCTAssertEqual(occasions.count, 1)
        XCTAssertEqual(occasions.first?.month, 3)
        XCTAssertEqual(occasions.first?.day, 9)
        XCTAssertEqual(occasions.first?.birthYear, 1990)
        let people = try HeldDear.ModelContext(opened.container).fetch(HeldDear.FetchDescriptor<Person>())
        XCTAssertEqual(people.first?.contactID, "contact-1")
    }

    func testTheOutputIsTheSameEveryTime() {
        XCTAssertEqual(CloudKitSchema.ckdb(for: model), CloudKitSchema.ckdb(for: model))
    }

    // MARK: The file in the repo

    private static let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The generator writes cloudkit/schema.ckdb (set WRITE_CLOUDKIT_SCHEMA=1 to rewrite it), and the file in the
    /// repo is always exactly what the model makes. A change to the model without a new file fails here.
    func testTheSchemaFileIsExactlyWhatTheModelMakes() throws {
        let url = Self.repo.appendingPathComponent("cloudkit/schema.ckdb")
        let made = CloudKitSchema.ckdb(for: model)
        if ProcessInfo.processInfo.environment["WRITE_CLOUDKIT_SCHEMA"] == "1" {
            try made.write(to: url, atomically: true, encoding: .utf8)
        }
        let saved = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(saved, made, "cloudkit/schema.ckdb is out of date: run this test with WRITE_CLOUDKIT_SCHEMA=1")
    }

    func testTheSchemaFileNamesNoEnvironmentAndNoSecretsAndOnlyCDTypes() throws {
        let saved = try String(contentsOf: Self.repo.appendingPathComponent("cloudkit/schema.ckdb"), encoding: .utf8)
        XCTAssertTrue(saved.hasPrefix("DEFINE SCHEMA"))
        for line in saved.split(separator: "\n") where line.contains("RECORD TYPE") {
            XCTAssertTrue(line.contains("RECORD TYPE CD_"), "\(line)")
        }
        XCTAssertFalse(saved.lowercased().contains("environment"))
    }
}
