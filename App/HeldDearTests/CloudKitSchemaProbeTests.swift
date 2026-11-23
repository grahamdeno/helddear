import XCTest
import CoreData
import OSLog
@testable import HeldDear

/// A probe, written first on purpose: does `initializeCloudKitSchema(options: [.dryRun, .printSchema])` run inside the
/// test host (CI: iOS simulator, CODE_SIGNING_ALLOWED=NO, no iCloud account), and can the printed schema be read back
/// from this process's log? The answer decides how the schema generator is built. It writes nothing to iCloud.
final class CloudKitSchemaProbeTests: XCTestCase {
    func testProbe_dryRunPrintsTheSchemaIntoTheProcessLog() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SchemaProbe-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let container = NSPersistentCloudKitContainer(name: "HeldDear", managedObjectModel: CoreStore.model)
        let description = NSPersistentStoreDescription(url: dir.appendingPathComponent("Probe.sqlite"))
        description.type = NSSQLiteStoreType
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: ICloudSync.containerID)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            XCTFail("PROBE: the store with a CloudKit container did not load in the test host: \(ICloudSync.reason(loadError as NSError))")
            return
        }

        let started = Date()
        do {
            try container.initializeCloudKitSchema(options: [.dryRun, .printSchema])
        } catch {
            XCTFail("PROBE: initializeCloudKitSchema(.dryRun, .printSchema) failed in the test host: \(ICloudSync.reason(error as NSError))")
            return
        }

        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let entries = try store.getEntries(at: store.position(date: started.addingTimeInterval(-1)))
            .compactMap { $0 as? OSLogEntryLog }
        let lines = entries.map(\.composedMessage)
        let schemaLines = lines.filter { $0.contains("DEFINE RECORD TYPE") || $0.contains("RECORD TYPE") || $0.contains("CD_") }
        print("PROBE: \(entries.count) log entries since the dry run, \(schemaLines.count) schema lines")
        print("PROBE: first schema lines:\n" + schemaLines.prefix(12).joined(separator: "\n"))
        add(XCTAttachment(string: lines.joined(separator: "\n")))
        XCTAssertFalse(schemaLines.isEmpty, "PROBE: the dry run finished but no schema text could be read from the process log")
    }
}
