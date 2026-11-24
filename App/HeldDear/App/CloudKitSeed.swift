#if DEBUG || SCHEMA_TEST
import CoreData
import Foundation

/// Debug builds only (never in a release build). The launch argument `-seedCloudKitOneOfEach` saves two made-up records
/// (one short, one long) of every record type, with every field filled, into a store of its own (never the user's store), then waits for
/// Core Data to send it to the CloudKit Development environment, writes "done" or the error to a file in the app's temp
/// folder, and quits. It is for a Mac or iPhone signed in to iCloud (routes A and B of the schema review): the long
/// strings and the 1 MB photo force the asset fields, so the schema Core Data creates can be exported and compared.
enum CloudKitSeed {
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("-seedCloudKitOneOfEach") }

    /// Each string of a long record. A record with several of them is over 1 MB in total, which forces the asset fields,
    /// while one record stays small enough for an iPhone (the first Schema Test build used 1,100,000 and was closed by
    /// iOS for memory).
    static let longStringLength = 300_000
    /// A photo over 1 MB.
    static let photoBytes = 1_200_000

    /// A short set uses values under 100 characters and a photo under 100 KB; a long set uses strings over 1 MB and a photo over 1 MB.
    static let shortPhotoBytes = 50_000

    typealias Made = (short: [String: NSManagedObject], long: [String: NSManagedObject])

    /// The record types in an order where every to-one link points at a type that comes earlier (Person first).
    static func order(of model: NSManagedObjectModel = CoreStore.model) -> [NSEntityDescription] {
        var left = model.entities.sorted { ($0.name ?? "") < ($1.name ?? "") }
        var out: [NSEntityDescription] = []
        while !left.isEmpty {
            let placed = Set(out.compactMap(\.name))
            let next = left.firstIndex { e in
                e.relationshipsByName.values.allSatisfy { r in
                    r.isToMany || r.destinationEntity?.name == e.name || placed.contains(r.destinationEntity?.name ?? "")
                }
            } ?? 0   // a cycle would be placed as it comes; the model has none
            out.append(left.remove(at: next))
        }
        return out
    }

    /// Saves nothing: makes two objects of every entity in `context` (one short, one long), every attribute filled
    /// (encrypted ones too) and every to-one link set within its own set.
    @discardableResult
    static func fill(_ context: NSManagedObjectContext, model: NSManagedObjectModel = CoreStore.model) -> Made {
        (short: fillSet(context, model: model, long: false), long: fillSet(context, model: model, long: true))
    }

    /// One object of every entity, short or long, linked to each other.
    static func fillSet(_ context: NSManagedObjectContext, model: NSManagedObjectModel = CoreStore.model, long: Bool) -> [String: NSManagedObject] {
        var made: [String: NSManagedObject] = [:]
        for entity in order(of: model) { made[entity.name!] = fillOne(context, entity: entity, long: long, linking: made) }
        return made
    }

    /// Makes a single record of one type with every attribute filled. Each to-one link points at the record of the
    /// destination type in `existing` (records already saved; pass faults to keep memory low).
    @discardableResult
    static func fillOne(_ context: NSManagedObjectContext, entity: NSEntityDescription, long: Bool,
                        linking existing: [String: NSManagedObject] = [:]) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: entity.name!, into: context)
        for (name, a) in entity.attributesByName { object.setValue(value(for: a, name: name, long: long), forKey: name) }
        for (name, r) in entity.relationshipsByName where !r.isToMany {
            if let target = existing[r.destinationEntity!.name!] { object.setValue(target, forKey: name) }
        }
        return object
    }

    /// An estimate of the memory one record's field values take while it is made and saved (Swift strings held as
    /// UTF-16 by Core Data, two bytes a character, plus binary data). Saving and exporting can briefly hold two or
    /// three copies of it.
    static func estimatedValueBytes(of entity: NSEntityDescription, long: Bool) -> Int {
        var total = 0
        for (_, a) in entity.attributesByName {
            switch a.attributeType {
            case .stringAttributeType: total += (long ? longStringLength : 13) * 2
            case .binaryDataAttributeType: total += a.allowsExternalBinaryDataStorage ? (long ? photoBytes : shortPhotoBytes) : 16
            default: total += 16
            }
        }
        return total
    }

    private static func value(for a: NSAttributeDescription, name: String, long: Bool) -> Any {
        switch a.attributeType {
        case .stringAttributeType:
            if !long { return "Made-up text." }
            return String(String(repeating: "Made-up text for the schema. ", count: longStringLength / 29 + 1).prefix(longStringLength))
        case .UUIDAttributeType: return UUID()
        case .dateAttributeType: return Date(timeIntervalSince1970: 1_800_000_000)
        case .booleanAttributeType: return true
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
            switch name { case "month": return 7; case "day": return 15; case "birthYear", "year": return 1990; default: return 3 }
        case .doubleAttributeType, .floatAttributeType: return 1.5
        case .binaryDataAttributeType:
            return Data(repeating: 7, count: a.allowsExternalBinaryDataStorage ? (long ? photoBytes : shortPhotoBytes) : 16)
        default: return Data(repeating: 7, count: 16)
        }
    }

    /// Seeds, waits for the export to finish, records the result, and quits. Never returns.
    static func runAndQuit() -> Never {
        let dir = FileManager.default.temporaryDirectory
        let done = dir.appendingPathComponent("seed-cloudkit-done.txt")
        var result = "error: the export did not finish within 5 minutes"
        let container = NSPersistentCloudKitContainer(name: "HeldDear", managedObjectModel: CoreStore.model)
        let description = NSPersistentStoreDescription(url: dir.appendingPathComponent("CloudKitSeed.sqlite"))
        description.type = NSSQLiteStoreType
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: ICloudSync.containerID)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var finished = false
        let observer = NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification,
                                                              object: container, queue: .main) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event, event.type == .export, event.endDate != nil else { return }
            result = event.succeeded ? "done" : "error: \(event.error.map { ICloudSync.reason($0 as NSError) } ?? "the export failed")"
            finished = true
        }
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            try? "error: \(ICloudSync.reason(loadError as NSError))".write(to: done, atomically: true, encoding: .utf8)
            exit(0)
        }
        do {
            fill(container.viewContext)
            try container.viewContext.save()
        } catch {
            try? "error: \(ICloudSync.reason(error as NSError))".write(to: done, atomically: true, encoding: .utf8)
            exit(0)
        }
        let end = Date().addingTimeInterval(300)
        while !finished && Date() < end { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.5)) }
        NotificationCenter.default.removeObserver(observer)
        try? result.write(to: done, atomically: true, encoding: .utf8)
        exit(0)
    }
}

/// Decides when one upload step of the Schema Test app is finished. Pure, so tests can run it with a fake clock and a
/// fake iCloud. Never reports "uploaded" while a record is missing or while there is nothing to compare, and never
/// stops before the failure or the limit.
enum SeedStepWait {
    enum Outcome: Equatable {
        case waiting
        case uploaded
        case rejected(String)
        case notInTime
    }

    /// The limit for one step.
    static let limit: TimeInterval = 180

    /// - expected: the records the step saved.
    /// - recordIDsKnown: how many of them Core Data has an iCloud record ID for yet (none until the export starts).
    /// - found: how many of those iCloud returned.
    /// - failure: the reason of an export that ended in failure after this step began, if any.
    static func evaluate(expected: Int, recordIDsKnown: Int, found: Int, failure: String?, elapsed: TimeInterval,
                         limit: TimeInterval = SeedStepWait.limit) -> Outcome {
        if expected > 0, recordIDsKnown == expected, found == expected { return .uploaded }
        if let failure { return .rejected(failure) }
        if elapsed >= limit { return .notInTime }
        return .waiting
    }
}

/// Where the Schema Test app's CloudKit notifications are observed. Core Data posts `eventChangedNotification` from
/// its own CloudKit queue and waits for every observer to return; an observer on the main queue made that queue wait
/// for the main thread while the main thread waited for it (the 0x8BADF00D crash of build 2). So the queue is nil:
/// the handler runs on the posting thread and never waits for the main thread.
enum SeedObserver {
    /// Never `.main`. nil runs the block on the thread that posts.
    static let queue: OperationQueue? = nil

    static func add(to center: NotificationCenter = .default, name: Notification.Name, object: Any?,
                    using block: @escaping (Notification) -> Void) -> NSObjectProtocol {
        center.addObserver(forName: name, object: object, queue: queue, using: block)
    }
}

/// Work that must never run on the main thread (reading iCloud record IDs from Core Data waits on the CloudKit queue).
enum SeedThread {
    /// Runs `work` on a background queue and hands the result back. Stops the app in a debug build, and in the Schema
    /// Test app, if it ever ran on the main thread.
    static func offMain<T>(_ work: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                assert(!Thread.isMainThread, "this work must never run on the main thread")
                continuation.resume(returning: work())
            }
        }
    }
}
#endif
