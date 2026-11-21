import Foundation
import CoreData
import UIKit

/// Item 3.1, sync and backup through the user's own private iCloud. Held Dear runs no server for this: Apple's
/// CloudKit container mirrors the store, photos travel as Photo records, and the You page settings travel in
/// iCloud's key-value store. Turning sync off keeps everything on this iPhone.
enum ICloudSync {
    static let containerID = "iCloud.com.grahamdeno.helddear"
    static let settingKey = "keepInICloud"

    /// The "Keep in iCloud" setting, on unless the user turned it off. Takes effect at the next launch.
    static var isOn: Bool {
        get { UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: settingKey) }
    }

    /// Which CloudKit environment this build uses (Info.plist, matching the entitlement). Development until the
    /// schema is deployed to production with Graham's go.
    static var environment: String { Bundle.main.object(forInfoDictionaryKey: "HeldDearCloudKitEnvironment") as? String ?? "Production" }

    /// The setting as it was when the store opened (a change applies at the next launch).
    static let isOnAtLaunch = isOn

    private static var observers: [NSObjectProtocol] = []
    private static var container: ModelContainer?
    private static var onChange: (() -> Void)?
    private static var tidyPending = false

    /// Starts photo and settings sync and the duplicate tidy-up. Call once, on the main thread, after the store opens.
    @MainActor
    static func start(_ container: ModelContainer, onChange: @escaping () -> Void) {
        self.container = container
        self.onChange = onChange
        let context = container.mainContext

        // Photos: every saved photo also becomes a Photo record; a photo whose file is missing (made on another
        // device) is written back from its record.
        PhotoStore.onSaved = { name, data in
            context.insert(PhotoObject(name: name, data: data))
            try? context.save()
        }
        PhotoStore.onDeleted = { name in
            for p in photos(named: name, in: context) { context.delete(p) }
            try? context.save()
        }
        PhotoStore.fetchMissing = { name in photos(named: name, in: context).first?.data }
        backfillPhotos(context)

        Settings.start()

        guard isOnAtLaunch else { return }
        let note = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange,
                                                          object: container.persistent.persistentStoreCoordinator,
                                                          queue: .main) { _ in
            MainActor.assumeIsolated { scheduleTidy() }
        }
        observers.append(note)
        initializeDevelopmentSchemaOnce(container.persistent)
    }

    static func photos(named name: String, in context: ModelContext) -> [PhotoObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Photo")
        request.predicate = NSPredicate(format: "name == %@", name)
        return ((try? context.moc.fetch(request)) ?? []).compactMap { $0 as? PhotoObject }
    }

    /// Photos saved before sync (or imported) get their records once.
    @MainActor
    static func backfillPhotos(_ context: ModelContext) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: PhotoStore.directory.path) else { return }
        let known = Set(((try? context.moc.fetch(NSFetchRequest<NSManagedObject>(entityName: "Photo"))) ?? [])
            .compactMap { ($0 as? PhotoObject)?.name })
        var added = 0
        for name in files where !known.contains(name) && !name.hasPrefix(".") {
            guard let data = try? Data(contentsOf: PhotoStore.url(name)) else { continue }
            context.insert(PhotoObject(name: name, data: data))
            added += 1
            if added % 20 == 0 { try? context.save() }
        }
        if added > 0 { try? context.save() }
    }

    @MainActor
    private static func scheduleTidy() {
        guard !tidyPending else { return }
        tidyPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            MainActor.assumeIsolated {
                tidyPending = false
                if let context = container?.mainContext, Duplicates.tidy(context) > 0 { try? context.save() }
                onChange?()
            }
        }
    }

    /// Creates the record types in the Development environment once, so they can be checked and then deployed to
    /// production (Graham's go). Never runs against production.
    private static func initializeDevelopmentSchemaOnce(_ persistent: NSPersistentCloudKitContainer) {
        let key = "cloudKitSchemaInitialized-31"
        guard environment == "Development", !UserDefaults.standard.bool(forKey: key) else { return }
        DispatchQueue.global(qos: .utility).async {
            do {
                try persistent.initializeCloudKitSchema(options: [])
                UserDefaults.standard.set(true, forKey: key)
            } catch {
                // No iCloud account or no network: tried again next launch.
            }
        }
    }

    /// The You page settings in iCloud's key-value store (Fable C5): own holidays, your name, sign-off, hidden
    /// photos, remembered places, which holidays you keep.
    enum Settings {
        static let keys = ["yourName", "cardSignature", CustomHolidays.defaultsKey, Holidays.defaultsKey,
                           "hiddenPhotoIDs", "rememberedPlaces"]
        private static var started = false

        static func start(local: UserDefaults = .standard, cloud: NSUbiquitousKeyValueStore = .default) {
            guard ICloudSync.isOnAtLaunch, !started else { return }
            started = true
            cloud.synchronize()
            pull(local: local, cloud: cloud, onlyMissing: true)
            push(local: local, cloud: cloud)
            observers.append(NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud, queue: .main) { _ in
                pull(local: local, cloud: cloud, onlyMissing: false)
                MainActor.assumeIsolated { ICloudSync.onChange?() }
            })
            observers.append(NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
                push(local: local, cloud: cloud)
            })
        }

        /// iCloud's values into this iPhone's settings. `onlyMissing`: on first launch, keep what's already here.
        static func pull(local: UserDefaults, cloud: NSUbiquitousKeyValueStore, onlyMissing: Bool) {
            pull(local: local, cloudValue: { cloud.object(forKey: $0) }, onlyMissing: onlyMissing)
        }

        static func pull(local: UserDefaults, cloudValue: (String) -> Any?, onlyMissing: Bool) {
            for key in keys {
                guard let value = cloudValue(key) else { continue }
                if onlyMissing, local.object(forKey: key) != nil { continue }
                local.set(value, forKey: key)
            }
        }

        static func push(local: UserDefaults, cloud: NSUbiquitousKeyValueStore) {
            for key in keys {
                if let value = local.object(forKey: key) { cloud.set(value, forKey: key) }
            }
            cloud.synchronize()
        }
    }
}

/// Duplicate rules for records that two devices can make for the same thing (Fable C4). The oldest record is kept;
/// what hangs off the others moves to it. Plain rules, unit tested.
enum Duplicates {
    /// Returns how many records were folded into others. Doesn't save.
    @discardableResult
    static func tidy(_ context: ModelContext) -> Int {
        var removed = 0
        // People imported from the same contact on two devices.
        let people = (try? context.fetch(FetchDescriptor<Person>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        var byContact: [String: Person] = [:]
        for p in people {
            guard let contact = p.contactID, !contact.isEmpty else { continue }
            if let keep = byContact[contact] {
                for o in p.occasions { o.person = keep }
                for w in p.wishes { w.person = keep }
                for l in p.ledger { l.person = keep }
                if keep.photoFiles.isEmpty { keep.photoFiles = p.photoFiles }
                context.delete(p)
                removed += 1
            } else {
                byContact[contact] = p
            }
        }
        // The same day for the same person (same kind, month and day).
        let occasions = (try? context.fetch(FetchDescriptor<Occasion>())) ?? []
        var byDay: [String: Occasion] = [:]
        for o in occasions.sorted(by: { $0.id.uuidString < $1.id.uuidString }) where !o.isDeleted {
            guard let person = o.person, !person.isDeleted else { continue }
            let key = "\(person.id)|\(o.typeRaw)|\(o.month)|\(o.day)|\(o.partnerName ?? "")"
            if let keep = byDay[key] {
                for m in o.moments { m.occasion = keep }
                context.delete(o)
                removed += 1
            } else {
                byDay[key] = o
            }
        }
        // One year of a day, made on two devices.
        let moments = (try? context.fetch(FetchDescriptor<Moment>(sortBy: [SortDescriptor(\.dueDate)]))) ?? []
        var byYear: [String: Moment] = [:]
        for m in moments where !m.isDeleted {
            guard let occasion = m.occasion, !occasion.isDeleted else { continue }
            let key = "\(occasion.id)|\(m.year)"
            if let keep = byYear[key] {
                for a in m.acts { a.moment = keep }
                context.delete(m)
                removed += 1
            } else {
                byYear[key] = m
            }
        }
        // A yearly line written twice for the same year of the same day.
        let ledger = (try? context.fetch(FetchDescriptor<LedgerEntry>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        var byLine: [String: LedgerEntry] = [:]
        for l in ledger where !l.isDeleted {
            guard let moment = l.momentID else { continue }
            let key = "\(l.person?.id.uuidString ?? "")|\(moment)"
            if byLine[key] != nil { context.delete(l); removed += 1 } else { byLine[key] = l }
        }
        // The same photo twice.
        let photos = ((try? context.moc.fetch(NSFetchRequest<NSManagedObject>(entityName: "Photo"))) ?? []).compactMap { $0 as? PhotoObject }
        var byName: Set<String> = []
        for p in photos.sorted(by: { $0.createdAt < $1.createdAt }) {
            if byName.contains(p.name) { context.delete(p); removed += 1 } else { byName.insert(p.name) }
        }
        return removed
    }
}
