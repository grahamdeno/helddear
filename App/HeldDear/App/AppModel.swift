import Contacts
import Foundation
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

/// Where a Moment's flow opens.
enum MomentStep: Equatable {
    /// Pick from the Moment's state (Home row taps).
    case auto
    case wishPrompt      // B3
    case choose          // C2
    case nextStep        // C3
    case mailCard        // Mail a real card (Handwrytten)
    case dayOf           // D1 opened in the app: call or message
    case photo           // D2
    case confirmCall     // E1, "Did you reach Mom?"
    case record          // E1
    case missed          // F1
}

enum Route: Identifiable, Equatable {
    case moment(UUID, MomentStep)
    case season(Date)
    case person(UUID)
    case addBirthday(String)
    case addWish(UUID?)
    case rings
    case settings
    case lifetime
    case ideas(UUID)

    var id: String {
        switch self {
        case .moment(let id, _): "moment-\(id)"
        case .season(let d): "season-\(d.timeIntervalSince1970)"
        case .person(let id): "person-\(id)"
        case .addBirthday: "add-birthday"
        case .addWish(let id): "add-wish-\(id?.uuidString ?? "")"
        case .rings: "rings"
        case .settings: "settings"
        case .lifetime: "lifetime"
        case .ideas(let id): "ideas-\(id)"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    @Published var route: Route?
    @Published var onboarded: Bool { didSet { defaults.set(onboarded, forKey: "onboarded") } }
    @Published var firstVisitCardDismissed: Bool { didSet { defaults.set(firstVisitCardDismissed, forKey: "firstVisitCardDismissed") } }
    @Published var notificationsAllowed = true
    /// Bumped after any change so lists that read the store directly redraw.
    @Published var revision = 0

    /// The Moment whose call the app just started.
    private var callMomentID: UUID?
    private let defaults = UserDefaults.standard
    /// The running model, for the background refresh task.
    static weak var current: AppModel?

    init(inMemory: Bool = false) {
        container = Store.makeContainer(inMemory: inMemory)
        onboarded = UserDefaults.standard.bool(forKey: "onboarded")
        firstVisitCardDismissed = UserDefaults.standard.bool(forKey: "firstVisitCardDismissed")

        NotificationService.shared.configure()
        NotificationService.shared.onOpen = { [weak self] kind, moment, month, action in
            self?.handleNotification(kind: kind, momentID: moment, monthStart: month, action: action)
        }
        CallService.shared.onConnected = { [weak self] in self?.callConnected() }
        AppModel.current = self
        _ = Purchases.shared
        NotificationCenter.default.addObserver(forName: .CNContactStoreDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.onboarded else { return }
                self.syncContacts()
                self.writeSnapshots()
                await self.scheduleAlerts()
                self.revision += 1
            }
        }
    }

    // MARK: Refresh

    /// Runs on launch and whenever the app becomes active.
    func refresh(now: Date = Date()) async {
        importInbox()
        if onboarded { syncContacts() }
        MomentEngine.refresh(context, now: now)
        checkReturnFromCall()
        writeSnapshots(now: now)
        let status = await NotificationService.shared.authorizationStatus()
        notificationsAllowed = status == .authorized || status == .provisional || status == .ephemeral
        await scheduleAlerts(now: now)
        revision += 1
    }

    func save() {
        try? context.save()
        revision += 1
    }

    /// Save, then bring alerts, the widget and the share-sheet people list up to date.
    func commit() {
        save()
        writeSnapshots()
        Task { await scheduleAlerts() }
    }

    func scheduleAlerts(now: Date = Date()) async {
        let moments = allMoments().filter { $0.person != nil && $0.dueDate >= Calendar.current.startOfDay(for: now).addingTimeInterval(-5 * 86400) }
        let states = moments.map(state(for:))
        let seasons = AlertPlanner.seasons(from: states, now: now)
        let result = AlertPlanner.plan(moments: states, seasons: seasons, now: now)
        for (id, date) in result.headsUpUpdates {
            moments.first { $0.id == id }?.headsUpAt = date
        }
        try? context.save()
        await NotificationService.shared.replace(with: result.alerts)
    }

    func state(for m: Moment) -> MomentState {
        let person = m.person
        let plan = m.plan
        return MomentState(id: m.id, personName: person?.name ?? "Someone", ring: m.occasion?.effectiveRing ?? .outer,
                           dueDate: m.dueDate, status: m.status, planKind: plan?.kind, planTitle: plan?.title, planDone: plan?.isDone ?? false,
                           greetingDone: m.greetingSent,
                           anyActDone: m.anyActDone, openWishCount: person?.openWishes.count ?? 0,
                           hasPhone: phone(for: person) != nil, turning: m.turning, headsUpAt: m.headsUpAt,
                           occasion: m.type, partnerName: m.occasion?.partnerName)
    }

    func seasons(now: Date = Date()) -> [Season] {
        AlertPlanner.seasons(from: allMoments().filter { $0.person != nil }.map(state(for:)), now: now)
    }

    // MARK: Lookups

    func allPeople() -> [Person] {
        ((try? context.fetch(FetchDescriptor<Person>())) ?? []).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func allMoments() -> [Moment] { (try? context.fetch(FetchDescriptor<Moment>())) ?? [] }

    func moment(_ id: UUID) -> Moment? { allMoments().first { $0.id == id } }
    func person(_ id: UUID) -> Person? { allPeople().first { $0.id == id } }

    /// The next open Moment for a person (their upcoming birthday).
    func nextMoment(for person: Person, now: Date = Date()) -> Moment? {
        let today = Calendar.current.startOfDay(for: now)
        return person.occasions.flatMap(\.moments).filter { $0.dueDate >= today }.sorted { $0.dueDate < $1.dueDate }.first
    }

    func phone(for person: Person?) -> String? {
        guard let person else { return nil }
        if let p = ContactsService.shared.phone(contactID: person.contactID) { return p }
        return person.manualPhone.flatMap { $0.isEmpty ? nil : $0 }
    }

    func address(for person: Person?) -> String? {
        ContactsService.shared.address(contactID: person?.contactID)
    }

    /// D2's photo set: last year's ledger photo, photos saved to the person, then the contact photo. Up to three.
    func photoChoices(for person: Person) -> [PhotoChoice] {
        var choices: [PhotoChoice] = []
        if let entry = person.sortedLedger.first(where: { $0.photoFile != nil }), let file = entry.photoFile,
           let image = PhotoStore.load(file) {
            choices.append(PhotoChoice(id: "ledger-\(file)", image: image, file: file, label: "From \(entry.year)"))
        }
        for file in person.photoFiles.reversed() where !choices.contains(where: { $0.file == file }) {
            if let image = PhotoStore.load(file) {
                choices.append(PhotoChoice(id: "saved-\(file)", image: image, file: file, label: "Saved for \(person.name)"))
            }
        }
        choices = Array(choices.prefix(2))
        if let contact = ContactsService.shared.photo(contactID: person.contactID) {
            choices.append(PhotoChoice(id: "contact", image: contact, file: nil, label: "\(person.name)'s contact photo"))
        }
        return Array(choices.prefix(3))
    }

    // MARK: People and dates

    /// Adds a person with a birthday, or changes an existing person's date.
    @discardableResult
    func addPerson(name: String, fullName: String?, contactID: String?, month: Int, day: Int, year: Int?, ring: Ring = .outer) -> Person {
        let person: Person
        if let existing = allPeople().first(where: { ($0.contactID != nil && $0.contactID == contactID) }) {
            person = existing
        } else {
            person = Person(name: name, fullName: fullName, contactID: contactID, ring: ring)
            context.insert(person)
        }
        setBirthday(person, month: month, day: day, year: year)
        return person
    }

    /// Adds a non-birthday occasion: an anniversary, a holiday, or a one-time life moment.
    func addOccasion(_ person: Person, type: OccasionType, month: Int, day: Int, year: Int?, partnerName: String? = nil) {
        if type.kind == .holiday, person.occasions.contains(where: { $0.type == type }) { return }
        let occasion = Occasion(type: type, month: month, day: day, birthYear: year)
        occasion.partnerName = partnerName
        context.insert(occasion)
        occasion.person = person
        MomentEngine.refresh(context)
        commit()
    }

    func removeOccasion(_ occasion: Occasion) {
        guard occasion.type != .birthday else { return }
        context.delete(occasion)
        commit()
    }

    func setBirthday(_ person: Person, month: Int, day: Int, year: Int?) {
        if let b = person.birthday {
            b.month = month; b.day = day
            if let year { b.birthYear = year }
        } else {
            let occasion = Occasion(month: month, day: day, birthYear: year)
            context.insert(occasion)
            occasion.person = person
        }
        MomentEngine.refresh(context)
        commit()
    }

    func delete(_ person: Person) {
        if let id = person.contactID {
            // Remembered so a re-sync never brings back someone the user removed.
            var removed = Set(defaults.stringArray(forKey: "removedContactIDs") ?? [])
            removed.insert(id)
            defaults.set(Array(removed), forKey: "removedContactIDs")
        }
        for file in person.photoFiles { PhotoStore.delete(file) }
        context.delete(person)
        commit()
    }

    // MARK: Contacts sync

    /// Brings in every birthday the app can see in Contacts and follows date changes made there.
    /// Runs on every open and whenever Contacts changes, so people shared later (limited access) arrive too.
    @discardableResult
    func syncContacts() -> Int {
        guard ContactsService.shared.canRead else { return 0 }
        let removed = Set(defaults.stringArray(forKey: "removedContactIDs") ?? [])
        var byContact: [String: Person] = [:]
        for p in allPeople() { if let id = p.contactID { byContact[id] = p } }
        var added = 0
        var changed = false
        for c in ContactsService.shared.allContacts() {
            guard let month = c.month, let day = c.day, BirthdayParser.isValid(month: month, day: day) else { continue }
            if let person = byContact[c.id] {
                if let b = person.birthday {
                    if b.month != month || b.day != day {
                        b.month = month; b.day = day; changed = true
                    }
                    if b.birthYear == nil, let y = c.year { b.birthYear = y; changed = true }
                } else {
                    let occasion = Occasion(month: month, day: day, birthYear: c.year)
                    context.insert(occasion)
                    occasion.person = person
                    changed = true
                }
            } else if !removed.contains(c.id) {
                let person = Person(name: c.displayName, fullName: c.fullName, contactID: c.id, ring: .outer)
                context.insert(person)
                let occasion = Occasion(month: month, day: day, birthYear: c.year)
                context.insert(occasion)
                occasion.person = person
                added += 1
                changed = true
            }
        }
        if changed {
            MomentEngine.refresh(context)
            save()
        }
        return added
    }

    // MARK: Wishes

    func addWish(to person: Person, text: String, url: String? = nil, imageFile: String? = nil, capturedAt: Date = Date()) {
        let wish = Wish(text: text, url: url, imageFile: imageFile, capturedAt: capturedAt)
        context.insert(wish)
        wish.person = person
        commit()
    }

    /// Files wishes saved from the share sheet.
    func importInbox() {
        let dir = AppGroup.inboxDir
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        var changed = false
        for file in files where file.pathExtension == "json" {
            defer { try? FileManager.default.removeItem(at: file) }
            guard let item = AppGroup.read(InboxWish.self, from: file), let person = self.person(item.personID) else { continue }
            let image = item.imageFile.flatMap { PhotoStore.adopt(fileAt: dir.appendingPathComponent($0)) }
            let wish = Wish(text: item.text, url: item.url, imageFile: image, capturedAt: item.capturedAt)
            context.insert(wish)
            wish.person = person
            changed = true
        }
        if changed { save() }
    }

    // MARK: Acts

    /// C2: the user picked one thing. Replaces any earlier unfinished plan.
    func choosePlan(_ m: Moment, kind: ActKind, title: String? = nil, wish: Wish? = nil) {
        for act in m.acts where act.role == .plan && !act.isDone { context.delete(act) }
        let act = Act(role: .plan, kind: kind, title: title ?? wish?.text, wishID: wish?.id)
        context.insert(act)
        act.moment = m
        m.status = .planning
        commit()
    }

    /// A Handwrytten card was paid for and placed: the plan is a card, and it's done.
    func mailedCard(_ m: Moment, cardName: String) {
        for act in m.acts where act.role == .plan && !act.isDone { context.delete(act) }
        let act = Act(role: .plan, kind: .card, title: "A handwritten card, mailed (\(cardName))")
        context.insert(act)
        act.moment = m
        act.complete(.mailed)
        m.status = .done
        commit()
    }

    /// The user picked a gift and ordered it: the plan becomes that gift, done, arriving on a date.
    func markOrdered(_ m: Moment, title: String, url: String?, wish: Wish?, arrivesBy: Date) {
        var w = wish
        if w == nil, let person = m.person {
            addWish(to: person, text: title, url: url)
            w = person.wishes.first { $0.text == title && $0.status == .open }
        }
        choosePlan(m, kind: .gift, title: title, wish: w)
        m.plan?.arrivesBy = arrivesBy
        completePlan(m)
    }

    func completePlan(_ m: Moment, how: ConfirmedBy = .user) {
        m.plan?.complete(how)
        if let wishID = m.plan?.wishID, let wish = m.person?.wishes.first(where: { $0.id == wishID }) {
            wish.status = .used
        }
        m.status = .done
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commit()
    }

    /// The day-of message or call. Completes a matching plan, otherwise records a greeting.
    func completeGreeting(_ m: Moment, kind: ActKind, how: ConfirmedBy, photoFile: String? = nil, cardFile: String? = nil) {
        if let plan = m.plan, !plan.isDone, plan.kind == kind {
            plan.photoFile = photoFile
            plan.cardFile = cardFile
            plan.complete(how)
        } else {
            let act = Act(role: .greeting, kind: kind)
            act.photoFile = photoFile
            act.cardFile = cardFile
            act.complete(how)
            context.insert(act)
            act.moment = m
        }
        if m.status == .missed { m.status = .lateSent } else { m.status = .done }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commit()
    }

    func letGo(_ m: Moment) {
        m.status = .letGo
        commit()
    }

    /// E1: adds the year to the person's ledger.
    func record(_ m: Moment, line: String?) {
        guard let person = m.person else { return }
        if person.ledger.contains(where: { $0.momentID == m.id }) { return }
        let photo = m.acts.compactMap(\.photoFile).first
        let entry = LedgerEntry(year: m.year, type: m.occasion?.type ?? .birthday, what: MomentEngine.whatWasDone(m),
                                photoFile: photo, line: line?.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                                personName: person.name, momentID: m.id)
        entry.cardFile = m.acts.compactMap(\.cardFile).first
        context.insert(entry)
        entry.person = person
        commit()
    }

    /// Last year's entry for the same occasion type, for C2's "Last year" line (G1).
    func lastYear(for m: Moment) -> LedgerEntry? {
        m.person?.sortedLedger.first { $0.year < m.year && $0.occasionTypeRaw == m.occasion?.typeRaw }
    }

    // MARK: Calls

    func startCall(_ m: Moment) -> Bool {
        guard let number = phone(for: m.person) else { return false }
        m.callStartedAt = Date()
        callMomentID = m.id
        save()
        return CallService.shared.call(number)
    }

    private func callConnected() {
        guard let id = callMomentID, let m = moment(id) else { return }
        callMomentID = nil
        CallService.shared.resolve()
        completeGreeting(m, kind: .call, how: .callConnected)
        route = .moment(id, .record)
    }

    /// Back from a call the app started with no connection seen: ask one question.
    private func checkReturnFromCall() {
        guard let id = callMomentID, let start = CallService.shared.pendingStart,
              Date().timeIntervalSince(start) > 5, !CallService.shared.sawConnection else { return }
        callMomentID = nil
        CallService.shared.resolve()
        route = .moment(id, .confirmCall)
    }

    // MARK: Notifications

    func handleNotification(kind: AlertKind?, momentID: UUID?, monthStart: Date?, action: String?) {
        if action == "confirm", let id = momentID { route = .moment(id, .confirmCall); return }
        guard let kind else { return }
        switch kind {
        case .wishPrompt: if let id = momentID { route = .moment(id, .wishPrompt) }
        case .headsUp, .nudge: if let id = momentID { route = .moment(id, .choose) }
        case .cutoff: if let id = momentID { route = .moment(id, .nextStep) }
        case .missed: if let id = momentID { route = .moment(id, .missed) }
        case .season: if let month = monthStart { route = .season(month) }
        case .grouped: route = nil
        case .dayOf:
            guard let id = momentID, let m = moment(id) else { return }
            switch action {
            case NotificationCategory.actionCall:
                if !startCall(m) { route = .moment(id, .photo) }
            case NotificationCategory.actionOpen:
                if let p = m.person { route = .person(p.id) }
            default:
                if phone(for: m.person) == nil, let p = m.person { route = .person(p.id) } else { route = .moment(id, .photo) }
            }
        }
    }

    func openURL(_ url: URL) {
        if url.scheme == "helddear", url.host() == "lifetime" { route = .lifetime; return }
        guard url.scheme == "helddear", url.host() == "moment",
              let idString = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value,
              let id = UUID(uuidString: idString) else { return }
        route = .moment(id, .auto)
    }

    // MARK: Snapshots for the share extension and widget

    func writeSnapshots(now: Date = Date()) {
        let people = allPeople().map { SharedPerson(id: $0.id, name: $0.name, isInner: $0.ring == .inner) }
        AppGroup.write(people, to: AppGroup.peopleURL)
        let next = MomentEngine.visibleMoments(context, now: now).filter { $0.dueDate >= Calendar.current.startOfDay(for: now) }.prefix(3).compactMap { m -> WidgetSnapshot.Entry? in
            guard let p = m.person else { return nil }
            let detail = m.countLine.map { $0.prefix(1).lowercased() + $0.dropFirst() }
            var soon: String?
            let days = OccasionDates.daysBetween(now, m.dueDate)
            if days <= 3 {
                let weekday = m.dueDate.formatted(.dateTime.weekday(.wide))
                switch NextAct.make(state(for: m), now: now) {
                case .orderBy: soon = "Order today"
                case .mailBy: soon = "Mail the card today"
                default: soon = days == 0 ? "Message ready today" : "Message ready \(weekday)"
                }
            }
            return WidgetSnapshot.Entry(momentID: m.id, name: p.name, occasion: m.type.label,
                                        dueDate: m.dueDate, detail: detail, soonLine: soon)
        }
        AppGroup.write(WidgetSnapshot(next: Array(next), writtenAt: now), to: AppGroup.widgetURL)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct PhotoChoice: Identifiable {
    var id: String
    var image: UIImage
    /// Nil for the contact photo, which is read live and copied only if picked.
    var file: String?
    var label: String
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
