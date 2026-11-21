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

    /// Opens a version 1 or 2 store through the migration plan. Writes to it (a version 1 store is migrated in
    /// place), so the app only ever calls this on a copy (`openCopy`).
    static func container(url: URL) throws -> SwiftData.ModelContainer {
        try SwiftData.ModelContainer(for: schema, migrationPlan: HeldDearMigrationPlan.self,
                                     configurations: [configuration(url: url)])
    }

    /// A copy of the old store's files in a temporary folder, opened. The original is only read (Fable S9).
    struct OpenedCopy {
        let container: SwiftData.ModelContainer
        let folder: URL
        /// Removes the temporary copy (never the original).
        func discard() { try? FileManager.default.removeItem(at: folder) }
    }

    static func openCopy(of url: URL) throws -> OpenedCopy {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appending(path: "HeldDearCopy-\(UUID().uuidString)")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appending(path: url.lastPathComponent)
        do {
            try fm.copyItem(at: url, to: copy)
            for suffix in ["-wal", "-shm"] where fm.fileExists(atPath: url.path + suffix) {
                try fm.copyItem(atPath: url.path + suffix, toPath: copy.path + suffix)
            }
            return OpenedCopy(container: try container(url: copy), folder: folder)
        } catch {
            try? fm.removeItem(at: folder)
            throw error
        }
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
    /// - the version 3 store opens (made if missing); if it won't open, it's tried once more, then kept aside under a
    ///   dated name and a fresh one opens (Fable S6);
    /// - if it isn't marked as copied, has no records, and a version 1 or 2 store exists (`legacyURL`, production when
    ///   nil), that store is copied in: the records and the "copied" mark go in one save, then everything is read back
    ///   and compared (Fable S2, S4). A version 3 store that already has records is never copied over;
    /// - the old store is never opened in place: a copy of its files is opened, so it's never written (Fable S9);
    /// - if the old store won't open or the copy fails, it stays where it is, the app runs in memory this launch and
    ///   says so, and the next launch tries again (Fable S1).
    /// `url` and `legacyURL` are for tests. `copyFromLegacy: false` skips looking for an old store (tests);
    /// `beforeCopySave` lets a test break the copy.
    static func open(inMemory: Bool = false, url: URL? = nil, legacyURL: URL? = nil, copyFromLegacy: Bool = true,
                     now: Date = Date(), beforeCopySave: ((ModelContext) throws -> Void)? = nil) -> OpenedStore {
        if inMemory { return OpenedStore(container: memoryContainer(), outcome: .opened, keptStoreURL: nil) }
        let storeURL = url ?? productionURL
        let oldURL = legacyURL ?? (url == nil ? LegacyStore.productionURL : nil)

        // Open version 3, trying twice before setting it aside.
        var outcome = OpenedStore.Outcome.opened
        var keptV3: URL?
        var persistent = makeContainer(url: storeURL)
        if (try? load(persistent)) == nil {
            persistent = makeContainer(url: storeURL)
            if (try? load(persistent)) == nil {
                let wasCopied = CopyMigration.fileSaysCopied(storeURL)
                keptV3 = try? keepAside(storeURL, now: now)
                persistent = makeContainer(url: storeURL)
                guard keptV3 != nil, (try? load(persistent)) != nil else {
                    return OpenedStore(container: memoryContainer(), outcome: .inMemoryThisLaunch, keptStoreURL: keptV3)
                }
                outcome = .freshStoreOldKeptAside
                // A store that had already been copied stays the user's latest; the old version 2 file is older.
                if wasCopied { CopyMigration.markCopiedWithoutRecords(persistent) }
            }
        }
        let container = ModelContainer(persistent: persistent)

        guard copyFromLegacy, let oldURL, FileManager.default.fileExists(atPath: oldURL.path),
              !CopyMigration.isCopied(persistent),
              ((try? container.mainContext.fetchCount(FetchDescriptor<Person>())) ?? 1) == 0,
              ((try? container.mainContext.fetchCount(FetchDescriptor<Occasion>())) ?? 1) == 0 else {
            return OpenedStore(container: container, outcome: outcome, keptStoreURL: keptV3)
        }

        // Copy from version 1 or 2, through a copy of its files.
        guard let legacy = try? LegacyStore.openCopy(of: oldURL) else {
            return OpenedStore(container: memoryContainer(), outcome: .inMemoryThisLaunch, keptStoreURL: oldURL)
        }
        do {
            let report = try CopyMigration.copy(from: SwiftData.ModelContext(legacy.container), to: container,
                                                beforeSave: beforeCopySave)
            legacy.discard()
            return OpenedStore(container: container, outcome: outcome, keptStoreURL: keptV3, copy: report)
        } catch {
            legacy.discard()
            // Nothing is lost: the old store is untouched, and the next launch tries again.
            return OpenedStore(container: memoryContainer(), outcome: .inMemoryThisLaunch, keptStoreURL: oldURL)
        }
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
