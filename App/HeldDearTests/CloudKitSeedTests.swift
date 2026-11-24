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

    func testShortValuesAreUnder100CharactersAndLongStringsOver250KAndEachLongRecordOverOneMegabyte() throws {
        let made = CloudKitSeed.fill(try context())
        XCTAssertEqual(CloudKitSeed.longStringLength, 300_000)
        for (_, object) in made.short {
            for (attr, a) in object.entity.attributesByName where a.attributeType == .stringAttributeType {
                XCTAssertLessThan((object.value(forKey: attr) as? String)?.count ?? 0, 100, "short \(object.entity.name!).\(attr)")
            }
        }
        for (name, object) in made.long {
            var total = 0
            for (attr, a) in object.entity.attributesByName {
                if a.attributeType == .stringAttributeType {
                    let count = (object.value(forKey: attr) as? String)?.count ?? 0
                    XCTAssertGreaterThan(count, 250_000, "long \(name).\(attr)")
                    total += count
                } else if a.attributeType == .binaryDataAttributeType {
                    total += (object.value(forKey: attr) as? Data)?.count ?? 0
                }
            }
            XCTAssertGreaterThan(total, 1_000_000, "long \(name): its text and data add up to over 1 MB")
        }
        XCTAssertLessThan((made.short["Photo"]?.value(forKey: "data") as? Data)?.count ?? .max, 100_000)
        XCTAssertGreaterThan((made.long["Photo"]?.value(forKey: "data") as? Data)?.count ?? 0, 1_000_000)
    }

    func testTheOrderPutsEveryLinkTargetBeforeItsRecordType() {
        let order = CloudKitSeed.order().compactMap(\.name)
        XCTAssertEqual(Set(order), Set(CoreStore.model.entities.compactMap(\.name)))
        XCTAssertEqual(order.count, 7)
        for entity in CoreStore.model.entities {
            for (_, r) in entity.relationshipsByName where !r.isToMany {
                XCTAssertLessThan(order.firstIndex(of: r.destinationEntity!.name!)!, order.firstIndex(of: entity.name!)!,
                                  "\(entity.name!) after \(r.destinationEntity!.name!)")
            }
        }
    }

    func testOneRecordTypeAtATimeLinksToRecordsAlreadySaved() throws {
        let context = try context()
        var saved: [String: NSManagedObject] = [:]
        for entity in CloudKitSeed.order() {
            let object = CloudKitSeed.fillOne(context, entity: entity, long: true, linking: saved)
            for (link, r) in entity.relationshipsByName where !r.isToMany {
                XCTAssertTrue((object.value(forKey: link) as? NSManagedObject) === saved[r.destinationEntity!.name!], "\(entity.name!).\(link)")
            }
            try context.save()
            saved[entity.name!] = object
            context.reset()   // as the Schema Test app does between steps
            saved = saved.mapValues { context.object(with: $0.objectID) }
        }
        XCTAssertEqual(saved.count, 7)
        let acts = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Act"))
        XCTAssertEqual(acts.count, 1)
        XCTAssertNotNil(acts.first?.value(forKey: "moment"))
    }

    func testTheLongActRecordFitsInAnEstimateOfAboutEightMegabytes() {
        let act = CoreStore.model.entitiesByName["Act"]!
        let strings = act.attributesByName.values.filter { $0.attributeType == .stringAttributeType }.count
        XCTAssertEqual(strings, 13)
        let bytes = CloudKitSeed.estimatedValueBytes(of: act, long: true)
        XCTAssertGreaterThan(bytes, 13 * 300_000 * 2)
        XCTAssertLessThan(bytes, 9_000_000, "the first build held about 28 MB for this one record")
    }
}

/// The deadlock of Schema Test build 2 (0x8BADF00D): Core Data posts its event notification from its CloudKit queue and
/// waits for each observer; an observer on the main queue made that queue wait for the main thread, which was itself
/// waiting for the CloudKit queue inside `recordIDs(for:)`.
final class SeedDeadlockTests: XCTestCase {
    func testTheObserverIsNeverOnTheMainQueue() {
        XCTAssertNil(SeedObserver.queue, "nil runs the handler on the posting thread")
        XCTAssertNotEqual(SeedObserver.queue, OperationQueue.main)
    }

    func testAPostFromAnotherThreadFinishesWhileTheMainThreadIsBlocked() {
        let center = NotificationCenter()
        let name = Notification.Name("SeedDeadlockTests.event")
        let handled = NSLock()
        var thread: Thread?
        let token = SeedObserver.add(to: center, name: name, object: nil) { _ in handled.lock(); thread = Thread.current; handled.unlock() }
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { center.post(name: name, object: nil); done.signal() }
        // The main thread waits here and runs nothing; the post must finish anyway.
        XCTAssertEqual(done.wait(timeout: .now() + 5), .success, "the post did not wait for the main thread")
        handled.lock(); defer { handled.unlock() }
        XCTAssertNotNil(thread)
        XCTAssertFalse(thread?.isMainThread ?? true, "the handler ran on the posting thread")
        center.removeObserver(token)
    }

    func testRecordIDWorkRunsOffTheMainThread() async {
        let onMain = await SeedThread.offMain { Thread.isMainThread }
        XCTAssertFalse(onMain)
    }
}

/// The step logic of the Schema Test app, with a fake clock and a fake iCloud.
final class SeedStepWaitTests: XCTestCase {
    func testAFourteenRecordRunWithNothingInICloudNeverReportsUploadedAndDoesNotStopEarly() {
        var elapsed: TimeInterval = 0
        var outcome = SeedStepWait.evaluate(expected: 14, recordIDsKnown: 0, found: 0, failure: nil, elapsed: elapsed)
        var ticks = 0
        while outcome == .waiting {
            XCTAssertNotEqual(outcome, .uploaded)
            elapsed += 3
            ticks += 1
            outcome = SeedStepWait.evaluate(expected: 14, recordIDsKnown: 0, found: 0, failure: nil, elapsed: elapsed)
            XCTAssertLessThan(ticks, 1000)
        }
        XCTAssertEqual(outcome, .notInTime)
        XCTAssertGreaterThanOrEqual(elapsed, SeedStepWait.limit, "it waited the whole limit")
        XCTAssertEqual(SeedStepWait.limit, 180)
        // Just before the limit it is still waiting.
        XCTAssertEqual(SeedStepWait.evaluate(expected: 14, recordIDsKnown: 0, found: 0, failure: nil, elapsed: 179), .waiting)
    }

    func testAnEmptyListOfIDsIsNeverUploaded() {
        XCTAssertEqual(SeedStepWait.evaluate(expected: 0, recordIDsKnown: 0, found: 0, failure: nil, elapsed: 0), .waiting)
        XCTAssertNotEqual(SeedStepWait.evaluate(expected: 7, recordIDsKnown: 0, found: 0, failure: nil, elapsed: 10), .uploaded)
    }

    func testUploadedNeedsEveryIDAndEveryRecord() {
        XCTAssertEqual(SeedStepWait.evaluate(expected: 7, recordIDsKnown: 7, found: 7, failure: nil, elapsed: 5), .uploaded)
        XCTAssertEqual(SeedStepWait.evaluate(expected: 7, recordIDsKnown: 7, found: 6, failure: nil, elapsed: 5), .waiting)
        XCTAssertEqual(SeedStepWait.evaluate(expected: 7, recordIDsKnown: 5, found: 5, failure: nil, elapsed: 5), .waiting, "two IDs are not known yet")
    }

    func testAFailedExportIsRejectedWithItsReasonAndTheLimitEndsTheStep() {
        XCTAssertEqual(SeedStepWait.evaluate(expected: 1, recordIDsKnown: 0, found: 0, failure: "field X", elapsed: 2), .rejected("field X"))
        XCTAssertEqual(SeedStepWait.evaluate(expected: 1, recordIDsKnown: 1, found: 0, failure: nil, elapsed: 181), .notInTime)
    }
}
