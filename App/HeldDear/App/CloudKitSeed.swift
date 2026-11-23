#if DEBUG
import CoreData
import Foundation

/// Debug builds only (never in a release build). The launch argument `-seedCloudKitOneOfEach` saves two made-up records
/// (one short, one long) of every record type, with every field filled, into a store of its own (never the user's store), then waits for
/// Core Data to send it to the CloudKit Development environment, writes "done" or the error to a file in the app's temp
/// folder, and quits. It is for a Mac or iPhone signed in to iCloud (routes A and B of the schema review): the long
/// strings and the 1 MB photo force the asset fields, so the schema Core Data creates can be exported and compared.
enum CloudKitSeed {
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("-seedCloudKitOneOfEach") }

    /// A string longer than this goes to an asset field (CloudKit keeps larger values outside the record).
    static let longStringLength = 1_100_000
    /// A photo over 1 MB.
    static let photoBytes = 1_200_000

    /// A short set uses values under 100 characters and a photo under 100 KB; a long set uses strings over 1 MB and a photo over 1 MB.
    static let shortPhotoBytes = 50_000

    typealias Made = (short: [String: NSManagedObject], long: [String: NSManagedObject])

    /// Saves nothing: makes two objects of every entity in `context` (one short, one long), every attribute filled
    /// (encrypted ones too) and every to-one link set within its own set.
    @discardableResult
    static func fill(_ context: NSManagedObjectContext, model: NSManagedObjectModel = CoreStore.model) -> Made {
        (short: fillOne(context, model: model, long: false), long: fillOne(context, model: model, long: true))
    }

    private static func fillOne(_ context: NSManagedObjectContext, model: NSManagedObjectModel, long: Bool) -> [String: NSManagedObject] {
        var made: [String: NSManagedObject] = [:]
        for entity in model.entities {
            let object = NSEntityDescription.insertNewObject(forEntityName: entity.name!, into: context)
            for (name, a) in entity.attributesByName { object.setValue(value(for: a, name: name, long: long), forKey: name) }
            made[entity.name!] = object
        }
        for entity in model.entities {
            for (name, r) in entity.relationshipsByName where !r.isToMany {
                made[entity.name!]?.setValue(made[r.destinationEntity!.name!], forKey: name)
            }
        }
        return made
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
#endif
