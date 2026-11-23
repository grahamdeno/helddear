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
                let field = CloudKitSchema.field(for: a).name
                XCTAssertEqual(body.filter { $0.hasPrefix("\"\(field)\" ") }.count, 1, "\(entity.name!).\(name)")
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
        XCTAssertTrue(occasion.contains("\"CD_month\" INT64,"))
        XCTAssertTrue(occasion.contains("\"CD_person\" STRING,"), "a to-one link is a STRING record name")
        let photo = lines(of: model.entitiesByName["Photo"]!, in: text)
        XCTAssertTrue(photo.contains("\"CD_data_ckAsset\" ASSET,"), "a large binary is an asset")
        XCTAssertFalse(photo.contains { $0.hasPrefix("\"CD_data\" ") }, "and has no second BYTES line")
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

    func testTheOwnerKeyOfAFamilyPageIsStillAFieldTheModelHas() {
        // Not a schema decision: the file mirrors the model. If a field is ever removed from the model, it leaves the file.
        XCTAssertNotNil(model.entitiesByName["Moment"]?.attributesByName["familyOwnerKey"])
        XCTAssertTrue(CloudKitSchema.ckdb(for: model).contains("\"CD_familyOwnerKey\" STRING,"))
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
