import Foundation

/// "Import my data" (Nov 21, 2026): puts an export from "Export my data" back into an empty store. Every record keeps
/// its id and links, the photos come back, and the settings in the export are restored. Everything is checked
/// against the export before the one save; if anything differs, nothing is saved and nothing is changed.
/// The export is only read. Contacts and the calendar are not touched.
enum DataImport {
    enum Failure: Error, Equatable {
        /// The app already has people or days; importing would mix two sets of plans.
        case notEmpty
        /// The file isn't an export from Held Dear.
        case notAnExport
        /// The records made don't match the export's counts or links.
        case checkFailed(String)
    }

    struct Summary: Equatable {
        var people = 0, occasions = 0, moments = 0, acts = 0, wishes = 0, ledger = 0, photos = 0
    }

    /// Whether the store is empty enough to import into: no people, days, parts, ideas or yearly lines.
    static func storeIsEmpty(_ context: ModelContext) -> Bool {
        ((try? context.fetchCount(FetchDescriptor<Person>())) ?? 1) == 0
            && ((try? context.fetchCount(FetchDescriptor<Occasion>())) ?? 1) == 0
            && ((try? context.fetchCount(FetchDescriptor<Act>())) ?? 1) == 0
            && ((try? context.fetchCount(FetchDescriptor<Wish>())) ?? 1) == 0
            && ((try? context.fetchCount(FetchDescriptor<LedgerEntry>())) ?? 1) == 0
    }

    /// Finds the export inside what the user picked: the zip, the unzipped folder, or the JSON file itself.
    /// A zip is unzipped into a temporary folder. Returns the folder that holds held-dear-data.json.
    static func exportFolder(fromPicked url: URL, workIn temp: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let fm = FileManager.default
        var root = url
        if url.pathExtension.lowercased() == "zip" {
            root = temp.appendingPathComponent("HeldDearImport-\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            try ZipReader.extract(url, to: root)
        } else if url.lastPathComponent == DataExport.jsonName {
            return url.deletingLastPathComponent()
        }
        if fm.fileExists(atPath: root.appendingPathComponent(DataExport.jsonName).path) { return root }
        if let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let file as URL in walker where file.lastPathComponent == DataExport.jsonName {
                return file.deletingLastPathComponent()
            }
        }
        throw Failure.notAnExport
    }

    /// Reads and restores an export folder. Photos go into `photosDirectory` (existing files are kept, never
    /// replaced); settings go into `defaults`.
    @discardableResult
    static func restore(folder: URL, into context: ModelContext, replacing: Bool = false,
                        photosDirectory: URL = PhotoStore.directory, defaults: UserDefaults = .standard) throws -> Summary {
        let doc: DataExport.Document
        do { doc = try DataExport.read(folder: folder) } catch { throw Failure.notAnExport }
        guard doc.format == "held-dear-export" else { throw Failure.notAnExport }
        return try restore(doc, photosFolder: folder.appendingPathComponent(DataExport.photosFolder, isDirectory: true),
                           into: context, replacing: replacing, photosDirectory: photosDirectory, defaults: defaults)
    }

    @discardableResult
    /// `replacing`: the user chose to replace what's on the phone with the export. What's there is removed and the
    /// export put in, in the same one save; if the check fails, nothing is removed.
    static func restore(_ doc: DataExport.Document, photosFolder: URL?, into context: ModelContext, replacing: Bool = false,
                        photosDirectory: URL = PhotoStore.directory, defaults: UserDefaults = .standard) throws -> Summary {
        guard replacing || storeIsEmpty(context) else { throw Failure.notEmpty }

        do {
            if replacing { try removeAll(from: context) }
            try insert(doc, into: context)
            try check(doc, against: context)
        } catch {
            context.moc.rollback()
            throw error
        }

        // Photos before the save, so a saved record never points at a photo that wasn't copied. Files already
        // there are kept as they are.
        var photos = 0
        if let photosFolder {
            let fm = FileManager.default
            try fm.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            for name in DataExport.photoFileNames(doc) {
                let source = photosFolder.appendingPathComponent(name)
                let target = photosDirectory.appendingPathComponent(name)
                guard !name.contains("/"), fm.fileExists(atPath: source.path) else { continue }
                if !fm.fileExists(atPath: target.path) { try fm.copyItem(at: source, to: target) }
                photos += 1
            }
        }

        do {
            try context.save()
        } catch {
            context.moc.rollback()
            throw error
        }
        if let settings = doc.settings { apply(settings, to: defaults) }
        return Summary(people: doc.people.count, occasions: doc.occasions.count, moments: doc.moments.count,
                       acts: doc.acts.count, wishes: doc.wishes.count, ledger: doc.ledger.count, photos: photos)
    }

    /// What's on the phone now, for counting in the replace question.
    static func current(_ context: ModelContext) -> (people: Int, parts: Int) {
        ((try? context.fetchCount(FetchDescriptor<Person>())) ?? 0, (try? context.fetchCount(FetchDescriptor<Act>())) ?? 0)
    }

    private static func removeAll(from context: ModelContext) throws {
        for r in try context.fetch(FetchDescriptor<Act>()) { context.delete(r) }
        for r in try context.fetch(FetchDescriptor<Wish>()) { context.delete(r) }
        for r in try context.fetch(FetchDescriptor<LedgerEntry>()) { context.delete(r) }
        for r in try context.fetch(FetchDescriptor<Moment>()) { context.delete(r) }
        for r in try context.fetch(FetchDescriptor<Occasion>()) { context.delete(r) }
        for r in try context.fetch(FetchDescriptor<Person>()) { context.delete(r) }
    }

    private static func insert(_ doc: DataExport.Document, into context: ModelContext) throws {
        var people: [UUID: Person] = [:]
        for r in doc.people {
            let p = Person(name: r.name, fullName: r.fullName, contactID: r.contactID)
            p.id = r.id
            p.manualPhone = r.manualPhone
            p.ringRaw = r.ring
            p.photoFiles = r.photoFiles
            p.createdAt = r.createdAt
            p.showAgeOnCard = r.showAgeOnCard
            p.loves = r.loves
            p.sizes = r.sizes
            p.goodToKnow = r.goodToKnow
            p.relationship = r.relationship
            p.mailingAddress = r.mailingAddress ?? doc.settings?.addresses?[r.id.uuidString]
            context.insert(p)
            people[r.id] = p
        }
        var occasions: [UUID: Occasion] = [:]
        for r in doc.occasions {
            let o = Occasion(type: .birthday, month: r.month, day: r.day, birthYear: r.birthYear)
            o.id = r.id
            o.typeRaw = r.type
            o.ringOverrideRaw = r.ringOverride
            o.extraRecipientIDs = r.extraRecipientIDs
            o.partnerName = r.partnerName
            context.insert(o)
            o.person = r.personID.flatMap { people[$0] }
            occasions[r.id] = o
        }
        var moments: [UUID: Moment] = [:]
        for r in doc.moments {
            let m = Moment(year: r.year, dueDate: r.dueDate)
            m.id = r.id
            m.statusRaw = r.status
            m.headsUpAt = r.headsUpAt
            m.callStartedAt = r.callStartedAt
            m.photoPromptShown = r.photoPromptShown
            m.missedAt = r.missedAt
            m.familyPageID = r.familyPageID
            m.familyInviteURL = r.familyInviteURL
            m.familyGiftURL = r.familyGiftURL
            context.insert(m)
            m.occasion = r.occasionID.flatMap { occasions[$0] }
            moments[r.id] = m
        }
        for r in doc.acts {
            let a = Act(role: .plan, kind: .other, title: r.title, wishID: r.wishID)
            a.id = r.id
            a.roleRaw = r.role
            a.kindRaw = r.kind
            a.fromNote = r.fromNote
            a.dinnerDate = r.dinnerDate
            a.arrivesBy = r.arrivesBy
            a.orderNumber = r.orderNumber
            a.trackingURL = r.trackingURL
            a.photoFile = r.photoFile
            a.cardFile = r.cardFile
            a.completedAt = r.completedAt
            a.confirmedRaw = r.confirmedBy
            a.createdAt = r.createdAt
            a.label = r.label
            a.step = r.step
            a.ownerIDs = r.ownerIDs
            a.note = r.note
            a.sortOrder = r.sortOrder
            context.insert(a)
            a.moment = r.momentID.flatMap { moments[$0] }
        }
        for r in doc.wishes {
            let w = Wish(text: r.text, url: r.url, imageFile: r.imageFile, capturedAt: r.capturedAt)
            w.id = r.id
            w.statusRaw = r.status
            context.insert(w)
            w.person = r.personID.flatMap { people[$0] }
        }
        for r in doc.ledger {
            let l = LedgerEntry(year: r.year, type: .birthday, what: r.what, photoFile: r.photoFile, line: r.line,
                                personName: r.personName, momentID: r.momentID)
            l.id = r.id
            l.occasionTypeRaw = r.occasionType
            l.cardFile = r.cardFile
            l.createdAt = r.createdAt
            context.insert(l)
            l.person = r.personID.flatMap { people[$0] }
        }
    }

    /// Counts and every link, compared with the export before anything is saved.
    private static func check(_ doc: DataExport.Document, against context: ModelContext) throws {
        let counts = try CopyMigration.counts(context)
        let expected = CopyMigration.Report(people: doc.people.count, occasions: doc.occasions.count,
                                            moments: doc.moments.count, acts: doc.acts.count,
                                            wishes: doc.wishes.count, ledger: doc.ledger.count)
        guard counts == expected else { throw Failure.checkFailed("counts") }

        var want = CopyMigration.Shape()
        var occasionsPerPerson: [UUID: Int] = [:], wishesPerPerson: [UUID: Int] = [:], ledgerPerPerson: [UUID: Int] = [:]
        for r in doc.occasions { want.occasions[r.id] = r.personID; if let p = r.personID { occasionsPerPerson[p, default: 0] += 1 } }
        for r in doc.moments { want.moments[r.id] = r.occasionID }
        for r in doc.acts { want.acts[r.id] = r.momentID }
        for r in doc.wishes { want.wishes[r.id] = r.personID; if let p = r.personID { wishesPerPerson[p, default: 0] += 1 } }
        for r in doc.ledger { want.ledger[r.id] = r.personID; if let p = r.personID { ledgerPerPerson[p, default: 0] += 1 } }
        for r in doc.people { want.people[r.id] = [occasionsPerPerson[r.id] ?? 0, wishesPerPerson[r.id] ?? 0, ledgerPerPerson[r.id] ?? 0] }
        // A link to a record that isn't in the export can't be made; the check expects it empty, as it reads back.
        let ids = (people: Set(doc.people.map(\.id)), occasions: Set(doc.occasions.map(\.id)), moments: Set(doc.moments.map(\.id)))
        for (k, v) in want.occasions where v.map({ !ids.people.contains($0) }) ?? false { want.occasions[k] = .some(nil) }
        for (k, v) in want.wishes where v.map({ !ids.people.contains($0) }) ?? false { want.wishes[k] = .some(nil) }
        for (k, v) in want.ledger where v.map({ !ids.people.contains($0) }) ?? false { want.ledger[k] = .some(nil) }
        for (k, v) in want.moments where v.map({ !ids.occasions.contains($0) }) ?? false { want.moments[k] = .some(nil) }
        for (k, v) in want.acts where v.map({ !ids.moments.contains($0) }) ?? false { want.acts[k] = .some(nil) }

        guard try CopyMigration.shape(of: context) == want else { throw Failure.checkFailed("links") }
    }

    private static func apply(_ s: DataExport.Settings, to defaults: UserDefaults) {
        if let name = s.yourName { defaults.set(name, forKey: "yourName") }
        if let signature = s.cardSignature { defaults.set(signature, forKey: "cardSignature") }
        if !s.customHolidays.isEmpty { CustomHolidays.save(s.customHolidays, defaults) }
        defaults.set(Holidays.offeredIn1_0.map(\.rawValue).filter(Set(s.enabledHolidays).contains), forKey: Holidays.defaultsKey)
        if !s.hiddenPhotoIDs.isEmpty { defaults.set(s.hiddenPhotoIDs, forKey: "hiddenPhotoIDs") }
        if let places = s.places, !places.isEmpty { PlaceStore(defaults: defaults).all = places }
        if let photo = s.yourPhotoFile { defaults.set(photo, forKey: YouProfile.photoKey) }
        if let birthday = s.yourBirthday { YouProfile.setBirthday(birthday, defaults) }
    }
}
