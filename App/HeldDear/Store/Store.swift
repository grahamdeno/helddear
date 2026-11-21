import Foundation
import CoreData
import SwiftData

// MARK: - The version 1 and 2 stores (SwiftData), read only to copy them into version 3

/// Version 1: the model as it shipped before 1.0. Its classes live in SchemaV1.swift and never change.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Person.self, Occasion.self, Moment.self, Wish.self, Act.self, LedgerEntry.self]
    }
}

/// Version 2: Held Dear 1.0 before the move to Core Data. Classes in Models.swift; never change.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Person.self, Occasion.self, Moment.self, Wish.self, Act.self, LedgerEntry.self]
    }
}

/// How a version 1 store reaches version 2 (lightweight: only added fields), before it's copied to version 3.
enum HeldDearMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

/// The SwiftData store from before version 3. Opened only to copy it; never written, never deleted.
enum LegacyStore {
    static let schema = Schema(versionedSchema: SchemaV2.self)

    /// Where builds before version 3 kept the store: no `url`, the default group container. With the App Group
    /// entitlement that is the shared container; unsigned runs (CI) fall back to Application Support.
    static func productionConfiguration() -> ModelConfiguration { ModelConfiguration(schema: schema) }
    static var productionURL: URL { productionConfiguration().url }

    static func configuration(url: URL) -> ModelConfiguration { ModelConfiguration(schema: schema, url: url) }

    /// Opens a version 1 or 2 store through the migration plan.
    static func container(url: URL) throws -> SwiftData.ModelContainer {
        try SwiftData.ModelContainer(for: schema, migrationPlan: HeldDearMigrationPlan.self,
                                     configurations: [configuration(url: url)])
    }
}

// MARK: - Opening the version 3 store

/// The opened store, and what happened when opening it.
struct OpenedStore {
    enum Outcome: Equatable {
        /// The saved store opened (or was copied from version 2), or an in-memory store was asked for.
        case opened
        /// The saved store couldn't be opened. The old file was kept aside, untouched, and a fresh store opened in
        /// its place; new plans are saved.
        case freshStoreOldKeptAside
        /// The saved store couldn't be opened or copied, and the app runs on a store held in memory for this launch
        /// only: nothing added is saved. The old file is left where it is, untouched, and the next launch tries again.
        case inMemoryThisLaunch
    }

    let container: ModelContainer
    let outcome: Outcome
    /// Where the plans that couldn't be opened are, untouched, so they can be exported.
    let keptStoreURL: URL?
    /// What the copy from version 2 did, when it ran this launch.
    var copy: CopyMigration.Report? = nil

    var couldNotOpenSavedStore: Bool { outcome != .opened }
}

enum Store {
    /// The version 3 store, next to where the version 2 store was.
    static var productionURL: URL {
        LegacyStore.productionURL.deletingLastPathComponent().appending(path: "HeldDear.sqlite")
    }

    /// The Core Data store at `url` (production when nil). No iCloud until item 3.1: the CloudKit container is set
    /// up but not connected. History tracking is on so turning sync on later needs no change to the store.
    static func makeContainer(url: URL?, inMemory: Bool = false) -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "HeldDear", managedObjectModel: CoreStore.model)
        let description = NSPersistentStoreDescription(url: inMemory ? URL(fileURLWithPath: "/dev/null") : (url ?? productionURL))
        description.type = NSSQLiteStoreType
        description.cloudKitContainerOptions = nil
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        return container
    }

    /// Loads a container's store, or throws.
    static func load(_ container: NSPersistentCloudKitContainer) throws {
        if let url = container.persistentStoreDescriptions.first?.url, url.path != "/dev/null" {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        var failure: Error?
        container.loadPersistentStores { _, error in failure = error }
        if let failure { throw failure }
    }

    /// Opens the store. Never crashes and never deletes anything:
    /// - a version 3 store opens as it is;
    /// - with none yet and a version 1 or 2 store (`legacyURL`, production when nil), that store is copied into a new
    ///   version 3 store and every count is checked; the old file stays where it is, untouched;
    /// - if the old store can't be opened, it's kept aside under a dated name and a fresh store opens;
    /// - if the copy fails, or no store opens at all, the app runs in memory this launch and says so.
    /// `url` and `legacyURL` are for tests. `copyFromLegacy: false` skips looking for an old store (tests).
    static func open(inMemory: Bool = false, url: URL? = nil, legacyURL: URL? = nil, copyFromLegacy: Bool = true,
                     now: Date = Date()) -> OpenedStore {
        if inMemory { return OpenedStore(container: memoryContainer(), outcome: .opened, keptStoreURL: nil) }
        let storeURL = url ?? productionURL
        let fm = FileManager.default
        let oldURL = legacyURL ?? (url == nil ? LegacyStore.productionURL : nil)

        // Already version 3.
        if fm.fileExists(atPath: storeURL.path), CopyMigration.isComplete(storeURL) {
            let c = makeContainer(url: storeURL)
            if (try? load(c)) != nil { return OpenedStore(container: ModelContainer(persistent: c), outcome: .opened, keptStoreURL: nil) }
            let kept = try? keepAside(storeURL, now: now)
            let fresh = makeContainer(url: storeURL)
            if kept != nil, (try? load(fresh)) != nil {
                CopyMigration.markComplete(fresh)
                return OpenedStore(container: ModelContainer(persistent: fresh), outcome: .freshStoreOldKeptAside, keptStoreURL: kept)
            }
            return OpenedStore(container: memoryContainer(), outcome: .inMemoryThisLaunch, keptStoreURL: kept ?? storeURL)
        }

        // A version 3 file left by a copy that didn't finish: put it aside (it's ours, from a failed copy) and start over.
        if fm.fileExists(atPath: storeURL.path) { _ = try? keepAside(storeURL, now: now) }

        let c = makeContainer(url: storeURL)
        guard (try? load(c)) != nil else {
            return OpenedStore(container: memoryContainer(), outcome: .inMemoryThisLaunch, keptStoreURL: nil)
        }
        let container = ModelContainer(persistent: c)

        // Copy from version 1 or 2, when there is one.
        if copyFromLegacy, let oldURL, fm.fileExists(atPath: oldURL.path) {
            let legacy: SwiftData.ModelContainer
            do {
                legacy = try LegacyStore.container(url: oldURL)
            } catch {
                // The old store can't be opened: keep it aside, untouched, and go on with the fresh store.
                let kept = try? keepAside(oldURL, now: now)
                CopyMigration.markComplete(c)
                return OpenedStore(container: container, outcome: .freshStoreOldKeptAside, keptStoreURL: kept ?? oldURL)
            }
            do {
                let report = try CopyMigration.copy(from: SwiftData.ModelContext(legacy), to: container.mainContext)
                CopyMigration.markComplete(c)
                return OpenedStore(container: container, outcome: .opened, keptStoreURL: nil, copy: report)
            } catch {
                // Nothing is lost: the old store is untouched and the next launch tries again.
                container.mainContext.moc.rollback()
                return OpenedStore(container: memoryContainer(), outcome: .inMemoryThisLaunch, keptStoreURL: oldURL)
            }
        }

        CopyMigration.markComplete(c)
        return OpenedStore(container: container, outcome: .opened, keptStoreURL: nil)
    }

    private static func memoryContainer() -> ModelContainer {
        let c = makeContainer(url: nil, inMemory: true)
        // An in-memory store with a valid model doesn't fail; if it ever did, nothing else could run either.
        try! load(c)
        return ModelContainer(persistent: c)
    }

    /// Moves the store and its -wal and -shm files next to it under a dated name ("default-kept-2026-11-20-131500.store"),
    /// leaving their contents untouched. Returns the kept store's address.
    static func keepAside(_ url: URL, now: Date) throws -> URL {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        var stamp = "\(base)-kept-\(f.string(from: now))"
        var n = 1
        while fm.fileExists(atPath: dir.appending(path: "\(stamp).\(ext)").path) {
            n += 1
            stamp = "\(base)-kept-\(f.string(from: now))-\(n)"
        }
        let kept = dir.appending(path: "\(stamp).\(ext)")
        try fm.moveItem(at: url, to: kept)
        for suffix in ["-wal", "-shm"] {
            let side = URL(fileURLWithPath: url.path + suffix)
            if fm.fileExists(atPath: side.path) {
                try? fm.moveItem(at: side, to: URL(fileURLWithPath: kept.path + suffix))
            }
        }
        return kept
    }
}
