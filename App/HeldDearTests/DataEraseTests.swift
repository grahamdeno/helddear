import CoreData
import XCTest
@testable import HeldDear

final class DataEraseTests: XCTestCase {
    func testClearRemovesSettingsButKeepsLifetimeAndICloudChoice() {
        let name = "erase-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.set("Ada", forKey: "yourName")
        d.set(true, forKey: "hasLifetime")
        d.set(false, forKey: ICloudSync.settingKey)
        DataErase.clear(d)
        XCTAssertNil(d.object(forKey: "yourName"))
        XCTAssertEqual(d.object(forKey: "hasLifetime") as? Bool, true)
        XCTAssertEqual(d.object(forKey: ICloudSync.settingKey) as? Bool, false)
        d.removePersistentDomain(forName: name)
    }

    func testEraseEmptiesTheStore() async throws {
        let container = Store.makeContainer(url: nil, inMemory: true)
        try Store.load(container)
        let ctx = container.viewContext
        for entity in container.managedObjectModel.entities { _ = NSEntityDescription.insertNewObject(forEntityName: entity.name!, into: ctx) }
        // Not saved on purpose: the erase must also clear unsaved objects.
        let suite = "erase-store-\(UUID().uuidString)"
        let local = UserDefaults(suiteName: suite)!
        local.set("Ada", forKey: "yourName")
        let photos = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        try Data([1]).write(to: photos.appendingPathComponent("a.jpg"))
        let outcome = await DataErase.eraseEverything(container: container, iCloud: false, local: local, group: nil,
                                                      photos: photos, systemSide: false)
        XCTAssertNil(local.object(forKey: "yourName"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: photos.path), "photos are gone")
        local.removePersistentDomain(forName: suite)
        XCTAssertEqual(outcome, .done)
        for entity in container.managedObjectModel.entities {
            XCTAssertEqual(try ctx.count(for: NSFetchRequest<NSManagedObject>(entityName: entity.name!)), 0, entity.name!)
        }
    }
}
