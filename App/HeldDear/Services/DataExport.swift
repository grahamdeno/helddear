import Foundation

/// "Export my data" (roadmap item 3.0a). Writes everything in the store to one zipped folder: a JSON file with every
/// person, occasion, moment, plan part, wish and yearly record, and a folder of every photo and card image they point
/// to. The file goes nowhere on its own: the You page hands it to the share sheet, and the user chooses where it goes.
/// Reads the store only; nothing is changed.
enum DataExport {
    static let jsonName = "held-dear-data.json"
    static let photosFolder = "photos"

    /// What was written. The counts are of records in the store, so a test can compare them with what went in.
    struct Summary: Equatable {
        var people = 0, occasions = 0, moments = 0, acts = 0, wishes = 0, ledger = 0
        /// Distinct image files copied into the photos folder.
        var photos = 0
        /// Image files a record names that weren't on the phone (left out, listed in the JSON).
        var missingPhotos: [String] = []
    }

    // MARK: Records (every stored field; raw values stay raw so nothing is lost)

    struct PersonRecord: Codable, Equatable {
        var id: UUID, name: String, fullName: String, contactID: String?, manualPhone: String?
        var ring: String, photoFiles: [String], createdAt: Date, showAgeOnCard: Bool
        var loves: [String], sizes: String?, goodToKnow: String?, relationship: String?
        var mailingAddress: MailAddress? = nil
    }
    struct OccasionRecord: Codable, Equatable {
        var id: UUID, type: String, month: Int, day: Int, birthYear: Int?, ringOverride: String?
        var extraRecipientIDs: [UUID], partnerName: String?, personID: UUID?
    }
    /// The family page owner key is a secret that only manages a page. It is not written to a file the user may share.
    struct MomentRecord: Codable, Equatable {
        var id: UUID, year: Int, dueDate: Date, status: String, headsUpAt: Date?, callStartedAt: Date?
        var photoPromptShown: Bool, missedAt: Date?, familyPageID: String?, familyInviteURL: String?
        var familyGiftURL: String?, occasionID: UUID?
    }
    struct ActRecord: Codable, Equatable {
        var id: UUID, role: String, kind: String, title: String?, wishID: UUID?, fromNote: String?
        var dinnerDate: Date?, arrivesBy: Date?, photoFile: String?, cardFile: String?, completedAt: Date?
        var confirmedBy: String?, createdAt: Date, momentID: UUID?
        var label: String?, step: String?, ownerIDs: [UUID], note: String?, sortOrder: Int
    }
    struct WishRecord: Codable, Equatable {
        var id: UUID, text: String, url: String?, imageFile: String?, capturedAt: Date, status: String, personID: UUID?
    }
    struct LedgerRecord: Codable, Equatable {
        var id: UUID, year: Int, occasionType: String, what: String, photoFile: String?, cardFile: String?
        var line: String?, momentID: UUID?, personName: String, createdAt: Date, personID: UUID?
    }

    /// What you set on the You page, kept in settings rather than the store (Opus review of PR #37: "everything"
    /// includes these).
    struct Settings: Codable, Equatable {
        var yourName: String?
        var cardSignature: String?
        var customHolidays: [CustomHoliday]
        var enabledHolidays: [String]
        var hiddenPhotoIDs: [String]
        /// Remembered places (story 2.12) and addresses kept for people (story 2.13), by person id.
        var places: [Place]? = nil
        var addresses: [String: MailAddress]? = nil
        /// Your photo and birthday (You page, Nov 21, 2026).
        var yourPhotoFile: String? = nil
        var yourBirthday: YouProfile.Day? = nil

        static func read(_ d: UserDefaults = .standard) -> Settings {
            Settings(yourName: d.string(forKey: "yourName"), cardSignature: d.string(forKey: "cardSignature"),
                     customHolidays: CustomHolidays.all(d),
                     enabledHolidays: Holidays.enabled(d).map(\.rawValue),
                     hiddenPhotoIDs: d.stringArray(forKey: "hiddenPhotoIDs") ?? [],
                     places: PlaceStore(defaults: d).all,
                     addresses: SavedAddresses(defaults: d).all,
                     yourPhotoFile: d.string(forKey: YouProfile.photoKey),
                     yourBirthday: YouProfile.birthday(d))
        }
    }

    struct Document: Codable, Equatable {
        var format = "held-dear-export"
        var formatVersion = 1
        var storeVersion: String
        var exportedAt: Date
        var counts: Counts
        var missingPhotos: [String]
        var people: [PersonRecord]
        var occasions: [OccasionRecord]
        var moments: [MomentRecord]
        var acts: [ActRecord]
        var wishes: [WishRecord]
        var ledger: [LedgerRecord]
        var settings: Settings? = nil
    }
    struct Counts: Codable, Equatable {
        var people: Int, occasions: Int, moments: Int, acts: Int, wishes: Int, ledger: Int, photos: Int
    }

    // MARK: Reading the store

    /// Every record in the store, found by fetching each type, so a record with a missing link is still included.
    static func document(from context: ModelContext, photoCount: Int = 0, missing: [String] = [], now: Date) throws -> Document {
        let people = try context.fetch(FetchDescriptor<Person>(sortBy: [SortDescriptor(\.createdAt)]))
        let occasions = try context.fetch(FetchDescriptor<Occasion>())
        let moments = try context.fetch(FetchDescriptor<Moment>(sortBy: [SortDescriptor(\.dueDate)]))
        let acts = try context.fetch(FetchDescriptor<Act>(sortBy: [SortDescriptor(\.createdAt)]))
        let wishes = try context.fetch(FetchDescriptor<Wish>(sortBy: [SortDescriptor(\.capturedAt)]))
        let ledger = try context.fetch(FetchDescriptor<LedgerEntry>(sortBy: [SortDescriptor(\.createdAt)]))
        return Document(
            storeVersion: CoreStore.version, exportedAt: now,
            counts: Counts(people: people.count, occasions: occasions.count, moments: moments.count, acts: acts.count,
                           wishes: wishes.count, ledger: ledger.count, photos: photoCount),
            missingPhotos: missing,
            people: people.map {
                PersonRecord(id: $0.id, name: $0.name, fullName: $0.fullName, contactID: $0.contactID,
                             manualPhone: $0.manualPhone, ring: $0.ringRaw, photoFiles: $0.photoFiles,
                             createdAt: $0.createdAt, showAgeOnCard: $0.showAgeOnCard, loves: $0.loves,
                             sizes: $0.sizes, goodToKnow: $0.goodToKnow, relationship: $0.relationship,
                             mailingAddress: $0.mailingAddress)
            },
            occasions: occasions.map {
                OccasionRecord(id: $0.id, type: $0.typeRaw, month: $0.month, day: $0.day, birthYear: $0.birthYear,
                               ringOverride: $0.ringOverrideRaw, extraRecipientIDs: $0.extraRecipientIDs,
                               partnerName: $0.partnerName, personID: $0.person?.id)
            },
            moments: moments.map {
                MomentRecord(id: $0.id, year: $0.year, dueDate: $0.dueDate, status: $0.statusRaw, headsUpAt: $0.headsUpAt,
                             callStartedAt: $0.callStartedAt, photoPromptShown: $0.photoPromptShown, missedAt: $0.missedAt,
                             familyPageID: $0.familyPageID, familyInviteURL: $0.familyInviteURL,
                             familyGiftURL: $0.familyGiftURL, occasionID: $0.occasion?.id)
            },
            acts: acts.map {
                ActRecord(id: $0.id, role: $0.roleRaw, kind: $0.kindRaw, title: $0.title, wishID: $0.wishID,
                          fromNote: $0.fromNote, dinnerDate: $0.dinnerDate, arrivesBy: $0.arrivesBy,
                          photoFile: $0.photoFile, cardFile: $0.cardFile, completedAt: $0.completedAt,
                          confirmedBy: $0.confirmedRaw, createdAt: $0.createdAt, momentID: $0.moment?.id,
                          label: $0.label, step: $0.step, ownerIDs: $0.ownerIDs, note: $0.note, sortOrder: $0.sortOrder)
            },
            wishes: wishes.map {
                WishRecord(id: $0.id, text: $0.text, url: $0.url, imageFile: $0.imageFile, capturedAt: $0.capturedAt,
                           status: $0.statusRaw, personID: $0.person?.id)
            },
            ledger: ledger.map {
                LedgerRecord(id: $0.id, year: $0.year, occasionType: $0.occasionTypeRaw, what: $0.what,
                             photoFile: $0.photoFile, cardFile: $0.cardFile, line: $0.line, momentID: $0.momentID,
                             personName: $0.personName, createdAt: $0.createdAt, personID: $0.person?.id)
            })
    }

    /// Every image file the records name, once each, in a steady order.
    static func photoFileNames(_ doc: Document) -> [String] {
        var names: [String] = []
        names += doc.people.flatMap(\.photoFiles)
        names += doc.wishes.compactMap(\.imageFile)
        names += doc.acts.flatMap { [$0.photoFile, $0.cardFile].compactMap { $0 } }
        names += doc.ledger.flatMap { [$0.photoFile, $0.cardFile].compactMap { $0 } }
        if let yours = doc.settings?.yourPhotoFile { names.append(yours) }
        var seen = Set<String>()
        return names.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    // MARK: Writing the folder

    /// Writes the JSON and the photos into `folder` (made if needed). `photosDirectory` is where the app keeps its
    /// images; tests pass their own.
    @discardableResult
    static func write(context: ModelContext, photosDirectory: URL, to folder: URL, now: Date = Date()) throws -> Summary {
        var doc = try document(from: context, now: now)
        doc.settings = Settings.read()
        return try write(doc, photosDirectory: photosDirectory, to: folder)
    }

    /// The file work alone (photos, JSON), so it can run off the main thread once the records are read.
    static func write(_ document: Document, photosDirectory: URL, to folder: URL) throws -> Summary {
        var doc = document
        let fm = FileManager.default
        let photoDir = folder.appendingPathComponent(photosFolder, isDirectory: true)
        try fm.createDirectory(at: photoDir, withIntermediateDirectories: true)
        var copied = 0
        var missing: [String] = []
        for name in photoFileNames(doc) {
            // A name is a plain file name. Anything with a path in it is left out rather than followed.
            guard !name.contains("/"), name != "..", name != "." else { missing.append(name); continue }
            let source = photosDirectory.appendingPathComponent(name)
            if fm.fileExists(atPath: source.path) {
                let target = photoDir.appendingPathComponent(name)
                if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
                try fm.copyItem(at: source, to: target)
                copied += 1
            } else {
                missing.append(name)
            }
        }
        doc.counts.photos = copied
        doc.missingPhotos = missing

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(doc).write(to: folder.appendingPathComponent(jsonName), options: .atomic)

        return Summary(people: doc.people.count, occasions: doc.occasions.count, moments: doc.moments.count,
                       acts: doc.acts.count, wishes: doc.wishes.count, ledger: doc.ledger.count,
                       photos: copied, missingPhotos: missing)
    }

    /// Reads a written export back, for tests and for checking a file.
    static func read(folder: URL) throws -> Document {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Document.self, from: Data(contentsOf: folder.appendingPathComponent(jsonName)))
    }

    // MARK: Zipping and sharing

    /// "HeldDear-data-2026-11-21".
    static func baseName(prefix: String = "HeldDear-data", now: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return "\(prefix)-\(f.string(from: now))"
    }

    /// Zips a folder with the system's own zip (a read coordinated "for uploading"), and returns a copy of the zip
    /// next to the folder. No outside code.
    static func zip(folder: URL, named name: String? = nil) throws -> URL {
        let fm = FileManager.default
        let target = folder.deletingLastPathComponent().appendingPathComponent((name ?? folder.lastPathComponent) + ".zip")
        if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinationError) { zipped in
            do { try fm.copyItem(at: zipped, to: target) } catch { copyError = error }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
        return target
    }

    /// The whole export for the You page: writes the folder, zips it, removes the loose folder, returns the zip.
    /// The export for the You page without holding up the screen (Opus review of PR #37): the records are read
    /// here, on the main thread, and the photos are copied and zipped in the background.
    @MainActor
    static func exportInBackground(context: ModelContext, photosDirectory: URL = PhotoStore.directory,
                                   in parent: URL = FileManager.default.temporaryDirectory,
                                   now: Date = Date()) async throws -> URL {
        var doc = try document(from: context, now: now)
        doc.settings = Settings.read()
        let snapshot = doc
        let folder = parent.appendingPathComponent(baseName(now: now), isDirectory: true)
        return try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            if fm.fileExists(atPath: folder.path) { try fm.removeItem(at: folder) }
            _ = try write(snapshot, photosDirectory: photosDirectory, to: folder)
            let zipped = try zip(folder: folder)
            try? fm.removeItem(at: folder)
            return zipped
        }.value
    }

    static func exportForSharing(context: ModelContext, photosDirectory: URL = PhotoStore.directory,
                                 in parent: URL = FileManager.default.temporaryDirectory,
                                 now: Date = Date()) throws -> (zip: URL, summary: Summary) {
        let name = baseName(now: now)
        let folder = parent.appendingPathComponent(name, isDirectory: true)
        let fm = FileManager.default
        if fm.fileExists(atPath: folder.path) { try fm.removeItem(at: folder) }
        let summary = try write(context: context, photosDirectory: photosDirectory, to: folder, now: now)
        let zipped = try zip(folder: folder)
        try? fm.removeItem(at: folder)
        return (zipped, summary)
    }

    // MARK: A store that couldn't be opened

    /// The saved plans the app couldn't open can't be read as records, so they are shared as they are: the kept store
    /// file with its -wal and -shm files, and the photos folder. This copies them into a new folder; nothing is
    /// changed or deleted.
    static func stageKeptStore(storeURL: URL, photosDirectory: URL = PhotoStore.directory,
                               in parent: URL = FileManager.default.temporaryDirectory, now: Date = Date()) throws -> URL {
        let fm = FileManager.default
        let folder = parent.appendingPathComponent(baseName(prefix: "HeldDear-saved-plans", now: now), isDirectory: true)
        if fm.fileExists(atPath: folder.path) { try fm.removeItem(at: folder) }
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try fm.copyItem(at: storeURL, to: folder.appendingPathComponent(storeURL.lastPathComponent))
        for suffix in ["-wal", "-shm"] {
            let side = URL(fileURLWithPath: storeURL.path + suffix)
            if fm.fileExists(atPath: side.path) {
                try fm.copyItem(at: side, to: folder.appendingPathComponent(side.lastPathComponent))
            }
        }
        if fm.fileExists(atPath: photosDirectory.path) {
            try fm.copyItem(at: photosDirectory, to: folder.appendingPathComponent(photosFolder, isDirectory: true))
        }
        return folder
    }

    /// The kept store, staged and zipped, ready for the share sheet.
    static func keptStoreBundle(storeURL: URL, photosDirectory: URL = PhotoStore.directory,
                                in parent: URL = FileManager.default.temporaryDirectory, now: Date = Date()) throws -> URL {
        let folder = try stageKeptStore(storeURL: storeURL, photosDirectory: photosDirectory, in: parent, now: now)
        let zipped = try zip(folder: folder)
        try? FileManager.default.removeItem(at: folder)
        return zipped
    }
}

/// When the app shows the "couldn't be opened" screen, and its words (item 3.0a).
enum StoreSetAside {
    static let message = "Your saved plans couldn't be opened. They're kept safe on this iPhone."
    static let exportTitle = "Export them"
    static let continueTitle = "Continue"

    /// Shown for both failure cases, once, until the user taps Continue.
    static func shouldShow(outcome: OpenedStore.Outcome, acknowledged: Bool) -> Bool {
        outcome != .opened && !acknowledged
    }

    /// Where the saved plans are: the kept-aside file if the app moved one, otherwise the file where it was.
    static func storeToExport(kept: URL?, original: URL?) -> URL? {
        let fm = FileManager.default
        if let kept, fm.fileExists(atPath: kept.path) { return kept }
        if let original, fm.fileExists(atPath: original.path) { return original }
        return nil
    }
}
