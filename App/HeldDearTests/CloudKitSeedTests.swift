import XCTest
import CoreData
@testable import HeldDear

/// `-seedCloudKitOneOfEach` (debug only): one made-up object of every record type, every field filled, long enough
/// to force the asset fields. These tests fill an in-memory store; nothing goes to iCloud.
final class CloudKitSeedTests: XCTestCase {
    /// Kept alive for the whole test: objects turn into empty faults when their container is released.
    private var container: NSPersistentContainer?

    private func context() throws -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "HeldDear", managedObjectModel: CoreStore.model)
        let d = NSPersistentStoreDescription()
        d.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [d]
        var failure: Error?
        container.loadPersistentStores { _, e in failure = e }
        XCTAssertNil(failure)
        self.container = container
        return container.viewContext
    }

    func testTwoObjectsOfEveryRecordTypeWithEveryFieldFilled() throws {
        let context = try context()
        let made = CloudKitSeed.fill(context)
        let names = Set(CoreStore.model.entities.compactMap(\.name))
        for (label, set) in [("short", made.short), ("long", made.long)] {
            XCTAssertEqual(Set(set.keys), names, "\(label): one of every record type")
            for (name, object) in set {
                for (attr, _) in object.entity.attributesByName {
                    XCTAssertNotNil(object.value(forKey: attr), "\(label) \(name).\(attr) is filled")
                }
                for (link, r) in object.entity.relationshipsByName where !r.isToMany {
                    let target = object.value(forKey: link) as? NSManagedObject
                    XCTAssertNotNil(target, "\(label) \(name).\(link) is set")
                    XCTAssertTrue(set.values.contains { $0 === target }, "\(label) \(name).\(link) links within its own set")
                }
            }
        }
        XCTAssertEqual(CoreStore.model.entities.count * 2, made.short.count + made.long.count)
        XCTAssertNoThrow(try context.save(), "the seed is a valid store")
    }

    func testEncryptedFieldsAreFilledInBothSets() throws {
        let made = CloudKitSeed.fill(try context())
        for set in [made.short, made.long] {
            for (_, object) in set {
                for (attr, a) in object.entity.attributesByName where a.allowsCloudEncryption {
                    XCTAssertNotNil(object.value(forKey: attr), "\(object.entity.name!).\(attr)")
                }
            }
        }
    }

    func testShortValuesAreUnder100CharactersAndLongStringsOverOneMegabyte() throws {
        let made = CloudKitSeed.fill(try context())
        for (_, object) in made.short {
            for (attr, a) in object.entity.attributesByName where a.attributeType == .stringAttributeType {
                XCTAssertLessThan((object.value(forKey: attr) as? String)?.count ?? 0, 100, "short \(object.entity.name!).\(attr)")
            }
        }
        for (_, object) in made.long {
            for (attr, a) in object.entity.attributesByName where a.attributeType == .stringAttributeType {
                XCTAssertGreaterThan((object.value(forKey: attr) as? String)?.count ?? 0, 1_000_000, "long \(object.entity.name!).\(attr)")
            }
        }
        XCTAssertLessThan((made.short["Photo"]?.value(forKey: "data") as? Data)?.count ?? .max, 100_000)
        XCTAssertGreaterThan((made.long["Photo"]?.value(forKey: "data") as? Data)?.count ?? 0, 1_000_000)
    }
}
