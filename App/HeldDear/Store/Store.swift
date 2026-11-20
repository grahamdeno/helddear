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

/// The opened store, and whether the saved one couldn't be opened.
struct OpenedStore {
    let container: ModelContainer
    /// True when the saved store couldn't be opened and the app started fresh. The app shows one calm line.
    let couldNotOpenSavedStore: Bool
    /// Where the old store was kept, untouched, if it could be moved aside.
    let keptStoreURL: URL?
}

enum Store {
    static let schema = Schema(versionedSchema: SchemaV2.self)

    /// The same place SwiftData uses by default, so existing stores are found where they already are.
    static var defaultURL: URL { URL.applicationSupportDirectory.appending(path: "default.store") }

    /// Opens the store through the migration plan. Never crashes: if the saved store can't be opened, it's moved
    /// aside under a dated name, untouched, and a fresh store opens in its place. If even that fails, the app runs
    /// on an in-memory store for this launch, so it never crashes in a loop.
    static func open(inMemory: Bool = false, url: URL? = nil, now: Date = Date()) -> OpenedStore {
        if inMemory {
            return OpenedStore(container: memoryContainer(), couldNotOpenSavedStore: false, keptStoreURL: nil)
        }
        let url = url ?? defaultURL
        do {
            return OpenedStore(container: try container(at: url), couldNotOpenSavedStore: false, keptStoreURL: nil)
        } catch {
            let kept = try? keepAside(url, now: now)
            if kept != nil, let fresh = try? container(at: url) {
                return OpenedStore(container: fresh, couldNotOpenSavedStore: true, keptStoreURL: kept)
            }
            return OpenedStore(container: memoryContainer(), couldNotOpenSavedStore: true, keptStoreURL: kept)
        }
    }

    static func container(at url: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let config = ModelConfiguration(schema: schema, url: url)
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
