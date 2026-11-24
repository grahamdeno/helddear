import CloudKit
import CoreData
import UIKit
import UserNotifications
import WidgetKit

/// "Delete all my data" (Fable's audit UX-13, Nov 24, 2026). Removes everything Held Dear keeps: every record on this
/// iPhone and, when "Keep in iCloud" is on, the same records in the user's own iCloud (Core Data's zone is purged,
/// so other devices remove them too), every saved photo, Held Dear's settings and its scheduled alerts. It never
/// touches Contacts, the photo library or calendar events already added. Purchases stay with the Apple account.
enum DataErase {
    /// Settings kept on purpose: the Lifetime unlock (Apple restores it anyway) and whether iCloud is on.
    static let keptDefaults: Set<String> = ["hasLifetime", ICloudSync.settingKey]

    enum Outcome: Equatable { case done, iCloudFailed(String) }

    @MainActor
    static func eraseEverything(container: NSPersistentCloudKitContainer, iCloud: Bool,
                                local: UserDefaults = .standard,
                                group: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier),
                                photos: URL = PhotoStore.directory,
                                systemSide: Bool = true) async -> Outcome {
        var outcome = Outcome.done
        let context = container.viewContext
        if iCloud, let store = container.persistentStoreCoordinator.persistentStores.first {
            let zone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
            let error: Error? = await withCheckedContinuation { done in
                container.purgeObjectsAndRecordsInZone(with: zone, in: store) { _, error in done.resume(returning: error) }
            }
            if let error { outcome = .iCloudFailed(ICloudSync.reason(error as NSError)) }
            context.reset()
        }
        // Whatever is left on this iPhone (everything, when iCloud is off or the purge failed).
        for entity in container.managedObjectModel.entities {
            guard let name = entity.name else { continue }
            let request = NSFetchRequest<NSManagedObject>(entityName: name)
            for object in (try? context.fetch(request)) ?? [] { context.delete(object) }
        }
        try? context.save()

        try? FileManager.default.removeItem(at: photos)
        clear(local)
        if let group { clear(group) }
        guard systemSide else { return outcome }
        let cloud = NSUbiquitousKeyValueStore.default
        for key in ICloudSync.Settings.keys { cloud.removeObject(forKey: key) }
        cloud.synchronize()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        WidgetCenter.shared.reloadAllTimelines()
        return outcome
    }

    static func clear(_ defaults: UserDefaults) {
        for key in defaults.dictionaryRepresentation().keys where !keptDefaults.contains(key) {
            defaults.removeObject(forKey: key)
        }
    }
}
