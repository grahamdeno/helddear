#if SCHEMA_TEST
import CloudKit
import CoreData
import SwiftUI

/// The Schema Test app (target HeldDearSchemaTest, compile flag SCHEMA_TEST; never part of the real app). On launch it
/// opens an empty store of its own, saves two made-up objects of every record type (a short set and a long set, every
/// field filled, photos under and over 1 MB, long strings that force the asset fields), waits for Core Data to send
/// them to the test container's iCloud, asks iCloud for each record, and shows one line per record type.
final class SchemaTestRunner: NSObject, ObservableObject {
    struct Row: Identifiable {
        let id: String
        let entity: String
        /// nil while waiting; "Uploaded" or the exact error.
        var result: String?
        var uploaded: Bool { result == "Uploaded" }
    }

    @Published private(set) var rows: [Row] = CoreStore.model.entities.compactMap(\.name).sorted().map { Row(id: $0, entity: $0, result: nil) }
    @Published private(set) var note = "Starting"
    @Published private(set) var finished = false

    private var container: NSPersistentCloudKitContainer?
    private var observer: NSObjectProtocol?
    private var exportErrors: [NSError] = []
    private var sawFailedExport = false
    private var started = false

    /// The top line.
    var headline: String {
        if !finished { return "Working: \(note)" }
        let count = rows.count
        return rows.allSatisfy(\.uploaded) ? "All \(count) record types uploaded" : "Something was rejected"
    }

    func start() {
        guard !started else { return }
        started = true
        Task { await run() }
    }

    @MainActor
    private func setNote(_ text: String) { note = text }

    @MainActor
    private func finish(allWith error: String) {
        for i in rows.indices where rows[i].result == nil { rows[i].result = error }
        finished = true
    }

    @MainActor
    private func run() async {
        let container = CKContainer(identifier: ICloudSync.containerID)
        setNote("checking the iCloud account")
        let account = try? await container.accountStatus()
        guard account == .available else {
            finish(allWith: "No iCloud account is signed in on this iPhone (status \(account.map { String($0.rawValue) } ?? "unknown")).")
            return
        }

        setNote("opening an empty store")
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // A new file name each launch keeps the store empty.
        let url = dir.appendingPathComponent("SchemaTest-\(UUID().uuidString).sqlite")
        let persistent = Store.makeContainer(url: url, cloud: true)
        self.container = persistent
        var loadError: Error?
        persistent.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            finish(allWith: "The store did not open: \(ICloudSync.reason(loadError as NSError))")
            return
        }

        observer = NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification,
                                                          object: persistent, queue: .main) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event, event.type == .export, event.endDate != nil else { return }
            if !event.succeeded {
                self?.sawFailedExport = true
                if let error = event.error { self?.exportErrors.append(error as NSError) }
            }
        }

        setNote("saving one of every record type")
        let context = persistent.viewContext
        let made = CloudKitSeed.fill(context)
        do { try context.save() } catch {
            finish(allWith: "Saving to the store failed: \(ICloudSync.reason(error as NSError))")
            return
        }

        // Which iCloud record belongs to which record type.
        var owner: [CKRecord.ID: String] = [:]
        let objects = Array(made.short.values) + Array(made.long.values)
        let ids = persistent.recordIDs(for: objects.map(\.objectID))
        for object in objects { if let id = ids[object.objectID] { owner[id] = object.entity.name } }

        setNote("waiting for the export to iCloud")
        let database = container.privateCloudDatabase
        let end = Date().addingTimeInterval(300)
        var found: [CKRecord.ID: CKRecord] = [:]
        while Date() < end {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            let fetched = (try? await database.records(for: Array(owner.keys), desiredKeys: [])) ?? [:]
            for (id, result) in fetched { if case .success(let record) = result { found[id] = record } }
            setNote("\(found.count) of \(owner.count) records are in iCloud")
            if found.count == owner.count || sawFailedExport { break }
        }
        if let observer { NotificationCenter.default.removeObserver(observer) }

        let reasons = Self.recordErrors(exportErrors)
        for i in rows.indices {
            let entity = rows[i].entity
            let mine = owner.filter { $0.value == entity }.map(\.key)
            let missing = mine.filter { found[$0] == nil }
            let wrongType = mine.compactMap { found[$0] }.filter { $0.recordType != "CD_\(entity)" }
            if mine.isEmpty {
                rows[i].result = "No record was made for \(entity)."
            } else if missing.isEmpty && wrongType.isEmpty {
                rows[i].result = "Uploaded"
            } else {
                let why = missing.compactMap { reasons.byRecord[$0] }.first ?? reasons.general
                rows[i].result = "Rejected. Record type CD_\(entity), \(missing.count) of \(mine.count) records missing. "
                    + (why ?? "iCloud reported no reason; the record is not in iCloud after the export.")
            }
        }
        finished = true
    }

    /// The reasons iCloud gave, per record where it named one, and the whole text otherwise. Looks through every
    /// underlying and partial error.
    static func recordErrors(_ errors: [NSError]) -> (byRecord: [CKRecord.ID: String], general: String?) {
        var byRecord: [CKRecord.ID: String] = [:]
        func walk(_ error: NSError, depth: Int) {
            guard depth < 6 else { return }
            if let partial = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: NSError] {
                for (key, value) in partial {
                    if let id = key as? CKRecord.ID { byRecord[id] = ICloudSync.reason(value) }
                    walk(value, depth: depth + 1)
                }
            }
            if let under = error.userInfo[NSUnderlyingErrorKey] as? NSError { walk(under, depth: depth + 1) }
            if let detailed = error.userInfo[NSDetailedErrorsKey] as? [NSError] { detailed.forEach { walk($0, depth: depth + 1) } }
        }
        errors.forEach { walk($0, depth: 0) }
        return (byRecord, errors.last.map { ICloudSync.reason($0) })
    }
}

struct SchemaTestView: View {
    @StateObject private var runner = SchemaTestRunner()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(runner.headline).font(.headline)
                    if !runner.finished { ProgressView() }
                }
                Section("Record types") {
                    ForEach(runner.rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CD_\(row.entity)").font(.body.weight(.semibold))
                            Text(row.result ?? "Waiting").font(.callout).foregroundStyle(row.uploaded ? .green : .primary)
                                .textSelection(.enabled)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle("Schema Test")
        }
        .task { runner.start() }
    }
}
#endif
