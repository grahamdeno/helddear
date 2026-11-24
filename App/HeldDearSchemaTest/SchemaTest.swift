#if SCHEMA_TEST
import CloudKit
import CoreData
import Darwin
import os
import SwiftUI

/// The Schema Test app (target HeldDearSchemaTest, compile flag SCHEMA_TEST; never part of the real app). It opens an
/// empty store of its own and sends made-up records to the test container's iCloud in steps, so the work never holds
/// much memory: first one short record of every record type (all at once), then the long records one record type at a
/// time. After each step it asks iCloud for the step's records and shows one line per record type.
///
/// Every step has a time limit, the screen always finishes, and every step is also written to
/// Documents/schema-test.txt, so the last step survives the app closing.
final class SchemaTestRunner: NSObject, ObservableObject {
    struct Row: Identifiable {
        let id: String
        let entity: String
        /// nil while waiting; "Uploaded" or the exact error.
        var result: String?
        var uploaded: Bool { result == "Uploaded" }
    }

    @Published private(set) var rows: [Row] = CoreStore.model.entities.compactMap(\.name).sorted().map { Row(id: $0, entity: $0, result: nil) }
    @Published private(set) var diagnostics: [String] = []
    @Published private(set) var progress = "Starting"
    @Published private(set) var stopped: String?
    @Published private(set) var finished = false

    private var container: NSPersistentCloudKitContainer?
    private var observer: NSObjectProtocol?
    private var exportErrors: [NSError] = []
    private var sawFailedExport = false
    private var started = false
    private var step = "starting"
    private var stepStartedAt = Date()

    /// The top line.
    var headline: String {
        if let stopped { return "Stopped: \(stopped)" }
        if !finished { return "Working: \(progress)" }
        let count = rows.count
        return rows.allSatisfy(\.uploaded) ? "All \(count) record types uploaded" : "Something was rejected"
    }

    func start() {
        guard !started else { return }
        started = true
        Task { await run() }
    }

    // MARK: diagnostics and the file

    private static let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("schema-test.txt")

    /// Appends a line to Documents/schema-test.txt.
    private func write(_ line: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let data = Data("\(stamp) [\(Self.footprintMB()) MB] \(line)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: Self.fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: Self.fileURL)
        }
    }

    private static func plistValue(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String).map { "\"\($0)\"" } ?? "(missing)"
    }

    private func gatherDiagnostics() {
        let group = AppGroup.identifier
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        diagnostics = [
            "Bundle ID: \(Bundle.main.bundleIdentifier ?? "(none)")",
            "Container used: \(ICloudSync.containerID)",
            "HeldDearCloudKitContainer: \(Self.plistValue("HeldDearCloudKitContainer"))",
            "HeldDearAppGroup: \(Self.plistValue("HeldDearAppGroup"))",
            "HeldDearCloudKitEnvironment: \(Self.plistValue("HeldDearCloudKitEnvironment"))",
            "Build number: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "(none)")",
            "App group container opens: \(groupURL != nil ? "yes" : "NO") (\(group))"
        ]
        diagnostics.forEach { write($0) }
    }

    // MARK: memory

    /// Memory the app is using now, in MB (the footprint iOS judges it by).
    static func footprintMB() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint / 1_048_576) : -1
    }

    private func refreshProgress() {
        let seconds = Int(Date().timeIntervalSince(stepStartedAt))
        let free = os_proc_available_memory() / 1_048_576
        progress = "\(step) · \(seconds) s · \(Self.footprintMB()) MB in use, \(free) MB free"
    }

    @MainActor
    private func begin(_ name: String) {
        step = name
        stepStartedAt = Date()
        refreshProgress()
        write("STEP \(name)")
    }

    // MARK: finishing

    @MainActor
    private func stop(_ reason: String, rows text: String) {
        stopped = reason
        write("STOPPED \(reason): \(text)")
        for i in rows.indices where rows[i].result == nil { rows[i].result = text }
        finished = true
    }

    // MARK: the account check, with a limit

    private enum AccountCheck {
        case status(CKAccountStatus)
        case error(NSError)
        case timedOut
    }

    /// Asks for the account status and gives up after `seconds`; the call itself has been seen never to return.
    private func accountCheck(limit seconds: TimeInterval) async -> AccountCheck {
        await withCheckedContinuation { continuation in
            let lock = NSLock()
            var done = false
            func finish(_ result: AccountCheck) {
                lock.lock(); defer { lock.unlock() }
                guard !done else { return }
                done = true
                continuation.resume(returning: result)
            }
            CKContainer(identifier: ICloudSync.containerID).accountStatus { status, error in
                if let error { finish(.error(error as NSError)) } else { finish(.status(status)) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { finish(.timedOut) }
        }
    }

    private static func describe(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: return "available"
        case .noAccount: return "no account"
        case .restricted: return "restricted"
        case .couldNotDetermine: return "could not determine"
        case .temporarilyUnavailable: return "temporarily unavailable"
        @unknown default: return "unknown (\(status.rawValue))"
        }
    }

    // MARK: the run

    private var owner: [CKRecord.ID: (entity: String, set: String)] = [:]
    /// What each step found: entity + set -> found in iCloud, and why a step did not succeed.
    private var found: Set<String> = []
    private var stepOutcomes: [String: SeedStepWait.Outcome] = [:]

    @MainActor
    private func run() async {
        gatherDiagnostics()
        let ticker = Task { @MainActor [weak self] in
            while let self, !self.finished {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.refreshProgress()
            }
        }
        defer { ticker.cancel() }

        begin("checking the iCloud account")
        let check = await accountCheck(limit: 20)
        switch check {
        case .timedOut:
            diagnostics.append("Account status: no answer after 20 seconds")
            stop("the iCloud account check", rows: "The iCloud account status did not answer within 20 seconds (container \(ICloudSync.containerID)).")
            return
        case .error(let error):
            diagnostics.append("Account status error: \(error.domain) \(error.code): \(error.localizedDescription)")
            stop("the iCloud account check", rows: "The iCloud account status failed: \(error.domain) \(error.code): \(error.localizedDescription).")
            return
        case .status(let status):
            diagnostics.append("Account status: \(Self.describe(status))")
            write("Account status: \(Self.describe(status))")
            guard status == .available else {
                stop("no usable iCloud account", rows: "iCloud account status: \(Self.describe(status)) (\(status.rawValue)).")
                return
            }
        }

        begin("opening an empty store")
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // A new file name each launch keeps the store empty.
        let url = dir.appendingPathComponent("SchemaTest-\(UUID().uuidString).sqlite")
        let persistent = Store.makeContainer(url: url, cloud: true)
        container = persistent
        var loadError: Error?
        persistent.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            stop("the store", rows: "The store did not open: \(ICloudSync.reason(loadError as NSError))")
            return
        }
        observer = NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification,
                                                          object: persistent, queue: .main) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event, event.type == .export, event.endDate != nil else { return }
            self?.write("export event ended, succeeded: \(event.succeeded)")
            if !event.succeeded {
                self?.sawFailedExport = true
                if let error = event.error { self?.exportErrors.append(error as NSError) }
            }
        }

        let context = persistent.viewContext
        let model = CoreStore.model
        let order = CloudKitSeed.order(of: model)

        // Step 1: the short set, all 7 at once.
        do {   // the objects are dropped when this block ends
            let shortObjects = CloudKitSeed.fillSet(context, model: model, long: false)
            await upload("short set", objects: Array(shortObjects.values), set: "short", persistent: persistent)
        }
        context.reset()

        // Steps 2 to 8: the long records, one record type at a time, linked to the long records already saved.
        var savedLong: [String: NSManagedObjectID] = [:]
        for entity in order {
            let name = entity.name!
            let object: NSManagedObject = autoreleasepool {
                let existing = savedLong.mapValues { context.object(with: $0) }   // faults: no text is loaded
                return CloudKitSeed.fillOne(context, entity: entity, long: true, linking: existing)
            }
            await upload("long CD_\(name)", objects: [object], set: "long", persistent: persistent)
            savedLong[name] = object.objectID
            context.reset()
        }
        if let observer { NotificationCenter.default.removeObserver(observer) }

        for i in rows.indices {
            let entity = rows[i].entity
            let parts = ["short", "long"].map { set -> String? in
                if found.contains("\(entity)/\(set)") { return nil }
                switch stepOutcomes["\(entity)/\(set)"] {
                case .rejected(let why)?: return "Rejected (\(set) record, record type CD_\(entity)). \(why)"
                default: return "Not uploaded in time (\(set) record, record type CD_\(entity))."
                }
            }.compactMap { $0 }
            rows[i].result = parts.isEmpty ? "Uploaded" : parts.joined(separator: " ")
            write("RESULT CD_\(entity): \(rows[i].result ?? "")")
        }
        progress = "done"
        finished = true
        write("FINISHED")
    }

    /// Saves one step's objects, then waits (at most `SeedStepWait.limit`) for iCloud to have all of them.
    @MainActor
    private func upload(_ name: String, objects: [NSManagedObject], set: String, persistent: NSPersistentCloudKitContainer) async {
        begin(name)
        guard let context = objects.first?.managedObjectContext else { return }
        do { try context.save() } catch {
            let why = "Saving to the store failed: \(ICloudSync.reason(error as NSError))"
            for o in objects { stepOutcomes["\(o.entity.name ?? "?")/\(set)"] = .rejected(why) }
            write(why)
            return
        }
        let ids = objects.map(\.objectID)
        var entityOf: [NSManagedObjectID: String] = [:]
        for o in objects { entityOf[o.objectID] = o.entity.name ?? "?" }
        exportErrors = []
        sawFailedExport = false
        let database = CKContainer(identifier: ICloudSync.containerID).privateCloudDatabase
        var foundHere: [NSManagedObjectID: Bool] = [:]
        var outcome = SeedStepWait.Outcome.waiting

        while outcome == .waiting {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            // Asked again every time: a record ID exists only after Core Data has started the export.
            let recordIDs = persistent.recordIDs(for: ids)
            var foundCount = 0
            if !recordIDs.isEmpty {
                let fetched = (try? await database.records(for: Array(recordIDs.values), desiredKeys: [])) ?? [:]
                for (objectID, recordID) in recordIDs {
                    if case .success(let record)? = fetched[recordID], record.recordType == "CD_\(entityOf[objectID] ?? "?")" {
                        foundHere[objectID] = true
                    }
                }
                foundCount = foundHere.count
            }
            let failure = sawFailedExport ? (Self.recordErrors(exportErrors).general ?? "The export failed with no reason given.") : nil
            outcome = SeedStepWait.evaluate(expected: ids.count, recordIDsKnown: recordIDs.count, found: foundCount, failure: failure,
                                            elapsed: Date().timeIntervalSince(stepStartedAt))
            write("\(name): \(recordIDs.count) of \(ids.count) record IDs, \(foundCount) in iCloud, \(String(describing: outcome))")
        }
        let reasons = Self.recordErrors(exportErrors)
        for id in ids {
            let key = "\(entityOf[id] ?? "?")/\(set)"
            if foundHere[id] == true { found.insert(key); continue }
            if case .rejected(let general) = outcome {
                let specific = persistent.recordIDs(for: [id])[id].flatMap { reasons.byRecord[$0] }
                stepOutcomes[key] = .rejected(specific ?? general)
            } else {
                stepOutcomes[key] = outcome
            }
        }
        write("\(name) result: \(String(describing: outcome))")
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
                Section("Diagnostics") {
                    ForEach(runner.diagnostics, id: \.self) { line in
                        Text(line).font(.footnote.monospaced()).textSelection(.enabled)
                    }
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
