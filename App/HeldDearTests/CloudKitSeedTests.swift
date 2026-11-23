import XCTest
import CoreData
@testable import HeldDear

/// `-seedCloudKitOneOfEach` (debug only): one made-up object of every record type, every field filled, long enough
/// to force the asset fields. These tests fill an in-memory store; nothing goes to iCloud.
final class CloudKitSeedTests: XCTestCase {
    private func context() throws -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "HeldDear", managedObjectModel: CoreStore.model)
        let d = NSPersistentStoreDescription()
        d.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [d]
        var failure: Error?
        container.loadPersistentStores { _, e in failure = e }
        XCTAssertNil(failure)
        return container.viewContext
    }

    func testOneObjectOfEveryRecordTypeWithEveryFieldFilled() throws {
        let context = try context()
        let made = CloudKitSeed.fill(context)
        XCTAssertEqual(Set(made.keys), Set(CoreStore.model.entities.compactMap(\.name)), "one of every record type")
        for (name, object) in made {
            for (attr, _) in object.entity.attributesByName {
                XCTAssertNotNil(object.value(forKey: attr), "\(name).\(attr) is filled")
            }
            for (link, r) in object.entity.relationshipsByName where !r.isToMany {
                XCTAssertNotNil(object.value(forKey: link), "\(name).\(link) is set")
            }
        }
        XCTAssertNoThrow(try context.save(), "the seed is a valid store")
    }

    func testStringsAreLongEnoughForTheAssetPathAndThePhotoIsOverOneMegabyte() throws {
        let made = CloudKitSeed.fill(try context())
        for (_, object) in made {
            for (attr, a) in object.entity.attributesByName where a.attributeType == .stringAttributeType {
                XCTAssertGreaterThan((object.value(forKey: attr) as? String)?.count ?? 0, 1_000_000, "\(object.entity.name!).\(attr)")
            }
        }
        let photo = made["Photo"]?.value(forKey: "data") as? Data
        XCTAssertGreaterThan(photo?.count ?? 0, 1_000_000)
    }
}
