import Foundation
import SwiftData

/// Version 1: the model as it shipped before 1.0. Its classes live in SchemaV1.swift and never change.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Person.self, Occasion.self, Moment.self, Wish.self, Act.self, LedgerEntry.self]
    }
}

/// Version 2: Held Dear 1.0. Adds plan-part fields to Act and a relationship to Person. Classes in Models.swift.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Person.self, Occasion.self, Moment.self, Wish.self, Act.self, LedgerEntry.self]
    }
}

/// How a store on the phone reaches the current version. Each stage only adds fields, so SwiftData moves the data
/// itself (lightweight); nothing is rewritten by the app.
enum HeldDearMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

/// The opened store, and what happened when opening it.
struct OpenedStore {
    enum Outcome: Equatable {
        /// The saved store opened (or was migrated), or an in-memory store was asked for.
        case opened
        /// The saved store couldn't be opened. The old file was kept aside, untouched, and a fresh store opened in
        /// its place; new plans are saved.
        case freshStoreOldKeptAside
        /// The saved store couldn't be opened and no fresh file could be opened either. The app runs on a store held
        /// in memory for this launch only: nothing added is saved. The old file is left where it is, or kept aside.
        case inMemoryThisLaunch
    }

    let container: ModelContainer
    let outcome: Outcome
    /// Where the old store was kept, untouched, if it could be moved aside.
    let keptStoreURL: URL?

    /// True for both failure cases. The app shows one calm line.
    var couldNotOpenSavedStore: Bool { outcome != .opened }
}

enum Store {
    static let schema = Schema(versionedSchema: SchemaV2.self)

    /// Where the store lives on a phone: built the way main built it, with no `url` and the default group container
    /// (`.automatic`). With the App Group entitlement that is the shared container, so a signed install finds the
    /// store that builds before 1.0 already made. Unsigned runs (CI) fall back to Application Support.
    static func productionConfiguration() -> ModelConfiguration {
        ModelConfiguration(schema: schema)
    }

    /// The production configuration, or one at `url`. A `url` is for tests only.
    static func configuration(url: URL?) -> ModelConfiguration {
        url.map { ModelConfiguration(schema: schema, url: $0) } ?? productionConfiguration()
    }

    /// Opens the store through the migration plan. Never crashes: if the saved store can't be opened, it's moved
    /// aside under a dated name, untouched, and a fresh store opens in its place. If that isn't possible either, the
    /// app runs on an in-memory store for this launch, so it never crashes in a loop. `outcome` says which happened.
    /// `url` is for tests only; the app passes nothing and gets the production location.
    static func open(inMemory: Bool = false, url: URL? = nil, now: Date = Date()) -> OpenedStore {
        if inMemory {
            return OpenedStore(container: memoryContainer(), outcome: .opened, keptStoreURL: nil)
        }
        let storeURL = configuration(url: url).url
        do {
            return OpenedStore(container: try container(configuration(url: url)), outcome: .opened, keptStoreURL: nil)
        } catch {
            let kept = try? keepAside(storeURL, now: now)
            if kept != nil, let fresh = try? container(configuration(url: url)) {
                return OpenedStore(container: fresh, outcome: .freshStoreOldKeptAside, keptStoreURL: kept)
            }
            return OpenedStore(container: memoryContainer(), outcome: .inMemoryThisLaunch, keptStoreURL: kept)
        }
    }

    static func container(_ config: ModelConfiguration) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: config.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return try ModelContainer(for: schema, migrationPlan: HeldDearMigrationPlan.self, configurations: [config])
    }

    private static func memoryContainer() -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // An in-memory store with a valid schema doesn't fail; if it ever did, nothing else could run either.
        return try! ModelContainer(for: schema, configurations: [config])
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
