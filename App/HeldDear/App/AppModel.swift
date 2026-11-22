import Contacts
import Foundation
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
    /// The occasion plan for a Moment (its id).
    case plan(UUID)
    /// A shared holiday's page: the occasion type's raw value and the year.
    case holiday(String, Int)

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
        case .plan(let id): "plan-\(id)"
        case .holiday(let type, let year): "holiday-\(type)-\(year)"
        }
    }
}

/// A page pushed from Home (version B, approved Nov 20, 2026). Home is the only root; every other page slides in
/// with a back link that names where you came from.
enum Nav: Hashable {
    /// A person's page; `focus` is the occasion (a Moment's id) to show first.
    case person(UUID, focus: UUID?)
    /// A shared holiday's page: the occasion type's raw value and the year.
    case holiday(String, Int)
    case people
    case ideas
    /// One item in a plan (an Act's id).
    case item(UUID)
    /// "Who is Ben to you?" for a person.
    case relationship(UUID)
    /// Everything else about a person, one page in from their page.
    case personDetails(UUID)
}

@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    /// What happened when the saved store was opened at launch. A screen shows one calm line for each failure case
    /// (worded later): `.freshStoreOldKeptAside` (old file kept on this phone, new plans are saved) and
    /// `.inMemoryThisLaunch` (nothing added this launch is saved).
    let storeOutcome: OpenedStore.Outcome
    var couldNotOpenSavedPlans: Bool { storeOutcome != .opened }
    var runningInMemoryThisLaunch: Bool { storeOutcome == .inMemoryThisLaunch }
    /// Where the old store was kept, if it could be moved aside.
    let keptStoreURL: URL?
    /// The "couldn't be opened" screen was answered (Continue) this launch.
    @Published var setAsideAcknowledged = false

    @Published var route: Route?
    /// Picked contacts still waiting for a date, shown one after another after Add a birthday closes.
    var contactsToDate: [String] = []
    /// Pages pushed from Home, oldest first.
    @Published var navPath: [Nav] = []
    @Published var onboarded: Bool { didSet { defaults.set(onboarded, forKey: "onboarded") } }
    @Published var firstVisitCardDismissed: Bool { didSet { defaults.set(firstVisitCardDismissed, forKey: "firstVisitCardDismissed") } }
    @Published var notificationsAllowed = true
    /// Bumped after any change so lists that read the store directly redraw.
    @Published var revision = 0
    /// Ideas whose link preview was asked for this launch, so a page is asked once.
    private var previewsAsked: Set<UUID> = []

    /// The Moment whose call the app just started.
    private var callMomentID: UUID?
    private let defaults = UserDefaults.standard
    /// The running model, for the background refresh task.
    static weak var current: AppModel?

    init(inMemory: Bool = false) {
        let opened = Store.open(inMemory: inMemory)
        container = opened.container
        storeOutcome = opened.outcome
        keptStoreURL = opened.keptStoreURL
        onboarded = UserDefaults.standard.bool(forKey: "onboarded")
        firstVisitCardDismissed = UserDefaults.standard.bool(forKey: "firstVisitCardDismissed")

        NotificationService.shared.configure()
        NotificationService.shared.onOpen = { [weak self] kind, moment, month, action in
            self?.handleNotification(kind: kind, momentID: moment, monthStart: month, action: action)
        }
        CallService.shared.onConnected = { [weak self] in self?.callConnected() }
        AppModel.current = self
        if !inMemory { ICloudSync.start(container) { [weak self] in self?.revision += 1 } }
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
        let isPlanMoment = m.isPlanMoment
        return MomentState(id: m.id, personName: person?.name ?? "Someone", ring: m.occasion?.effectiveRing ?? .outer,
                           dueDate: m.dueDate, status: m.status, planKind: plan?.kind, planTitle: plan?.label ?? plan?.title,
                           planDone: plan?.isDone ?? false,
                           greetingDone: m.greetingSent,
                           anyActDone: m.anyActDone, openWishCount: person?.openWishes.count ?? 0,
                           hasPhone: phone(for: person) != nil, turning: m.turning, headsUpAt: m.headsUpAt,
                           occasion: m.type, partnerName: m.occasion?.partnerName,
                           partsReady: isPlanMoment ? m.partsReady : 0,
                           partsTotal: isPlanMoment ? m.planParts.count : 0,
                           isPlanMoment: isPlanMoment)
    }

    func seasons(now: Date = Date()) -> [Season] {
        AlertPlanner.seasons(from: allMoments().filter { $0.person != nil }.map(state(for:)), now: now)
    }

    // MARK: Lookups

    func allPeople() -> [Person] {
        ((try? context.fetch(FetchDescriptor<Person>())) ?? []).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func allMoments() -> [Moment] { (try? context.fetch(FetchDescriptor<Moment>())) ?? [] }

    // MARK: Pages pushed from Home

    /// The page a route opens when it's a page rather than a flow: people, holidays and plans slide in from Home.
    func navTarget(for route: Route) -> Nav? {
        switch route {
        case .person(let id): return .person(id, focus: nil)
        case .plan(let id): return moment(id)?.person.map { .person($0.id, focus: id) }
        case .holiday(let raw, let year): return .holiday(raw, year)
        case .rings: return .people
        default: return nil
        }
    }

    func push(_ nav: Nav) {
        guard navPath.last != nav else { return }
        navPath.append(nav)
    }

    /// The back link's words on a pushed page: the page before it, or Home.
    func backTitle(for nav: Nav) -> String {
        guard let i = navPath.firstIndex(of: nav), i > 0 else { return "Home" }
        return title(of: navPath[i - 1])
    }

    func title(of nav: Nav) -> String {
        switch nav {
        case .person(let id, _): return person(id).map { DisplayName.plain($0.name) } ?? "Back"
        case .holiday(let raw, _): return HolidayRef(raw: raw)?.label ?? "Back"
        case .people: return "Everyone"
        case .ideas: return "Ideas"
        case .relationship: return "Who they are"
        case .personDetails(let id): return person(id).map { "\(DisplayName.plain($0.name))'s details" } ?? "Back"
        case .item(let id): return act(id).map { PartSteps.displayName(kindRaw: $0.kindRaw, label: $0.label, title: $0.title) } ?? "Back"
        }
    }

    func act(_ id: UUID) -> Act? { allMoments().flatMap(\.acts).first { $0.id == id } }

    /// Who an item can be from: the household (a partner and the children) first, then anyone else in the inner
    /// ring, other than the person it's for. The item page shows the household and puts the rest under "Someone
    /// else" (feedback on build 1017).
    func household(for person: Person?) -> [Person] {
        let people = allPeople().filter { $0.id != person?.id }
        let core = people.filter { [.partner, .child].contains(Relationship.group($0.relationship)) }
        let inner = people.filter { $0.ring == .inner && !core.contains($0) }
        return core + inner
    }

    func moment(_ id: UUID) -> Moment? { allMoments().first { $0.id == id } }
    func person(_ id: UUID) -> Person? { allPeople().first { $0.id == id } }

    /// The other half of an anniversary, for the two-photo circles (nil when there's nothing to pair).
    func pairPartner(for moment: Moment) -> PairSide? {
        guard let occasion = moment.occasion, let owner = moment.person else { return nil }
        return AnniversaryPair.partner(type: occasion.type, partnerName: occasion.partnerName,
                                       extraRecipientIDs: occasion.extraRecipientIDs, ownerID: owner.id,
                                       people: allPeople().map { .init(id: $0.id, name: $0.name, fullName: $0.fullName) },
                                       yourName: UserDefaults.standard.string(forKey: "yourName") ?? "")
    }

    /// A person's own next day (birthday, anniversary, life moment), leaving out shared holidays.
    func nextPersonalMoment(for person: Person, now: Date = Date()) -> Moment? {
        let today = Calendar.current.startOfDay(for: now)
        return person.occasions.filter { $0.type.kind != .holiday }.flatMap(\.moments)
            .filter { $0.dueDate >= today }.sorted { $0.dueDate < $1.dueDate }.first
    }

    /// Upcoming shared holidays, one each: which holiday, its date and how many people are in it.
    func upcomingHolidays(now: Date = Date()) -> [(ref: HolidayRef, year: Int, date: Date, people: Int)] {
        let today = Calendar.current.startOfDay(for: now)
        let moments = allMoments().filter { $0.type.kind == .holiday && $0.person != nil && $0.dueDate >= today }
        let groups = Dictionary(grouping: moments) { m in
            Holidays.groupKey(type: m.type, year: m.year, partner: m.occasion?.partnerName) ?? m.type.rawValue
        }
        return groups.values.compactMap { g in
            guard let f = g.first else { return nil }
            return (HolidayRef(type: f.type, name: f.occasion?.partnerName), f.year, f.dueDate, g.count)
        }.sorted { $0.date < $1.date }
    }

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
        if let a = ContactsService.shared.address(contactID: person?.contactID) { return a }
        return person?.mailingAddress?.oneLine
    }

    /// The person's ZIP code, from Contacts or the address kept in the app (story 2.14).
    func zip(for person: Person?) -> String? {
        if let a = ContactsService.shared.mailAddress(contactID: person?.contactID), let z = Places.zip(in: a.zip) { return z }
        return Places.zip(in: person?.mailingAddress?.zip)
    }

    /// The photo set for cards: last year's record photo, every photo saved to the person (top one first), then the contact photo.
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
        // Every saved photo is offered (feedback on build 1021), after last year's.
        if let contact = ContactsService.shared.photo(contactID: person.contactID) {
            choices.append(PhotoChoice(id: "contact", image: contact, file: nil, label: "\(person.name)'s contact photo"))
        }
        return choices
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

    /// Adds a person with their first date, whatever it's for: a birthday, an anniversary or a life moment. A
    /// one-time moment typed without a year is its next one.
    @discardableResult
    func addPerson(name: String, fullName: String?, contactID: String?, firstDate type: OccasionType,
                   month: Int, day: Int, year: Int?, eventName: String? = nil) -> Person {
        if type == .birthday {
            return addPerson(name: name, fullName: fullName, contactID: contactID, month: month, day: day, year: year)
        }
        let person: Person
        if let existing = allPeople().first(where: { $0.contactID != nil && $0.contactID == contactID }) {
            person = existing
        } else {
            person = Person(name: name, fullName: fullName, contactID: contactID, ring: .outer)
            context.insert(person)
        }
        let when = year ?? (type.kind == .once ? Calendar.current.component(.year, from: OccasionDates.nextDate(month: month, day: day, onOrAfter: Calendar.current.startOfDay(for: Date()))) : nil)
        addOccasion(person, type: type, month: month, day: day, year: when, partnerName: type == .event ? eventName : nil)
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

    /// A saved idea that's a link gets the page's title and image once (Nov 21, 2026). A link typed or pasted as the
    /// idea's words becomes its link. Kept with the idea; the page isn't asked again.
    func addPreview(to wish: Wish) {
        if wish.url == nil, let found = LinkPreviews.link(in: wish.text) { wish.url = found.absoluteString }
        guard let link = wish.url.flatMap(URL.init(string:)) else { return }
        let needsTitle = wish.text.isEmpty || LinkPreviews.isOnlyALink(wish.text)
        guard needsTitle || wish.imageFile == nil else { return }
        guard !previewsAsked.contains(wish.id) else { return }
        previewsAsked.insert(wish.id)
        Task { @MainActor in
            let preview = await LinkPreviews.fetch(link)
            if needsTitle { wish.text = preview.title ?? LinkPreviews.shortName(link) }
            if wish.imageFile == nil, let image = preview.image { wish.imageFile = PhotoStore.save(image, maxSide: 900) }
            save()
        }
    }

    func addWish(to person: Person, text: String, url: String? = nil, imageFile: String? = nil, capturedAt: Date = Date()) {
        let wish = Wish(text: text, url: url, imageFile: imageFile, capturedAt: capturedAt)
        context.insert(wish)
        wish.person = person
        commit()
        addPreview(to: wish)
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
        PlanStore.removeOldFlowPlans(of: m, in: context)
        let act = Act(role: .plan, kind: kind, title: title ?? wish?.text, wishID: wish?.id)
        context.insert(act)
        act.moment = m
        m.status = .planning
        commit()
    }

    /// A Handwrytten card was paid for and placed: the plan is a card, and it's done.
    func mailedCard(_ m: Moment, cardName: String) {
        PlanStore.removeOldFlowPlans(of: m, in: context)
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

    // MARK: Occasion plan (roadmap Epic 2)

    /// The user picked a step for a part. Reaching the ready step completes it; leaving it undoes that.
    /// Returns false, changing nothing, when the free plan limit stops it (roadmap 2.7); the screen offers Lifetime.
    @discardableResult
    func setStep(_ act: Act, _ step: String) -> Bool {
        if step != "open", let person = act.moment?.person,
           !PlanLimit.allows(personID: person.id, plannedPeople: plannedPeople(), hasLifetime: Purchases.shared.hasLifetime) {
            return false
        }
        PlanStore.setStep(act, to: step)
        commit()
        return true
    }

    /// People with a plan: any part moved past Not started (roadmap 2.7).
    func plannedPeople() -> Set<UUID> {
        var ids = Set<UUID>()
        for m in allMoments() {
            guard let p = m.person else { continue }
            if m.planParts.contains(where: { ($0.step ?? "open") != "open" }) { ids.insert(p.id) }
        }
        return ids
    }

    /// The shelf feeds the gift (roadmap 2.5): a saved wish becomes the part's idea.
    @discardableResult
    func pickWish(_ wish: Wish, for act: Act) -> Bool {
        act.title = wish.text
        act.wishID = wish.id
        if (act.currentStep ?? "open") == "open" {
            return setStep(act, "idea")
        }
        commit()
        return true
    }

    /// A find becomes the item's idea: saved to the person's shelf with its link, then chosen for the item, with a
    /// note naming the maker and the order-by date when the item has no note yet.
    @discardableResult
    func useFind(_ find: Find, for act: Act) -> Bool {
        guard let person = act.moment?.person else { return false }
        addWish(to: person, text: find.name, url: find.url)
        guard let wish = person.wishes.first(where: { $0.text == find.name && $0.url == find.url && $0.status == .open }) else { return false }
        if act.note == nil, let due = act.moment?.dueDate { act.note = Finds.meta(find, due: due) }
        return pickWish(wish, for: act)
    }

    func dismissFind(_ find: Find, for person: Person) {
        Finds.dismiss(find.id, for: person.id)
        revision += 1
    }

    /// A link for an item (what was bought, tracking): kept with the item through a shelf entry, so nothing new is
    /// stored. Replaces the item's link if it had one from a shelf entry.
    func attachLink(_ url: URL, to act: Act) {
        guard let person = act.moment?.person else { return }
        let text = act.title ?? PartSteps.displayName(kindRaw: act.kindRaw, label: act.label, title: act.title)
        if let id = act.wishID, let wish = person.wishes.first(where: { $0.id == id }) {
            wish.url = url.absoluteString
        } else {
            let wish = Wish(text: text, url: url.absoluteString)
            wish.status = .used   // a link for this item, not an idea for the shelf
            context.insert(wish)
            wish.person = person
            act.wishID = wish.id
            if act.title == nil { act.title = text }
        }
        commit()
    }

    func setRelationship(_ person: Person, _ relationship: String?) {
        person.relationship = relationship?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        commit()
    }

    // MARK: Shared holidays (roadmap Epic 1)

    /// Every person's moment for one holiday in one year, by name.
    func holidayMembers(ref: HolidayRef, year: Int) -> [Moment] {
        allMoments().filter { ref.matches(type: $0.type, partner: $0.occasion?.partnerName) && $0.year == year && $0.person != nil }
            .sorted { ($0.person?.name ?? "").localizedCaseInsensitiveCompare($1.person?.name ?? "") == .orderedAscending }
    }

    /// A person joining a shared holiday starts with what families usually plan for them (roadmap 1.6). Only a plan
    /// with nothing in it is started; nothing else is ever changed here.
    func startHolidayPlan(_ m: Moment) {
        guard m.type.kind == .holiday, !m.acts.contains(where: { $0.role == .plan }) else { return }
        for s in PartSuggestions.holidayStart(for: m.type, relationship: m.person?.relationship) {
            PlanStore.addPart(to: m, kind: s.kind, label: s.label, in: context)
        }
        commit()
    }

    /// Adds a person to a shared holiday and starts their plan.
    func addToHoliday(_ person: Person, ref: HolidayRef, year: Int) {
        if !person.occasions.contains(where: { ref.matches(type: $0.type, partner: $0.partnerName) }) {
            let custom = ref.type == .custom ? CustomHolidays.find(ref.name ?? "") : nil
            if ref.type == .custom && custom == nil { return }
            let occasion = Occasion(type: ref.type, month: custom?.month ?? ref.type.fixedHoliday?.month ?? 1,
                                    day: custom?.day ?? ref.type.fixedHoliday?.day ?? 1)
            occasion.partnerName = custom?.name
            context.insert(occasion)
            occasion.person = person
            MomentEngine.refresh(context)
        }
        if let m = holidayMembers(ref: ref, year: year).first(where: { $0.person?.id == person.id }) {
            startHolidayPlan(m)
        }
        commit()
    }

    // MARK: Holidays the user adds (story 2.10)

    /// Adds a holiday with the same date each year, for the people chosen.
    func addCustomHoliday(_ holiday: CustomHoliday, people: [Person], now: Date = Date()) {
        CustomHolidays.upsert(holiday)
        let year = Calendar.current.component(.year, from: now)
        for p in people { addToHoliday(p, ref: holiday.ref, year: year) }
        MomentEngine.refresh(context)
        commit()
    }

    /// Renames or moves a holiday: every person's day follows, including this year's if it hasn't happened.
    func updateCustomHoliday(old: String, to holiday: CustomHoliday) {
        CustomHolidays.upsert(holiday, replacing: old)
        let occasions = (try? context.fetch(FetchDescriptor<Occasion>())) ?? []
        for o in occasions where o.type == .custom && CustomHolidays.sameName(o.partnerName ?? "", old) {
            o.partnerName = holiday.name
            o.month = holiday.month
            o.day = holiday.day
            let today = Calendar.current.startOfDay(for: Date())
            for m in o.moments where !m.status.isSettled && m.dueDate >= today {
                m.dueDate = OccasionDates.date(month: holiday.month, day: holiday.day, year: m.year)
                m.headsUpAt = nil
            }
        }
        MomentEngine.refresh(context)
        commit()
    }

    /// Removes a holiday from every timeline. Past years stay in each person's record.
    func removeCustomHoliday(_ name: String) {
        CustomHolidays.remove(name)
        let occasions = (try? context.fetch(FetchDescriptor<Occasion>())) ?? []
        for o in occasions where o.type == .custom && CustomHolidays.sameName(o.partnerName ?? "", name) {
            context.delete(o)
        }
        commit()
    }

    /// How many people are in a holiday the user added.
    func customHolidayPeople(_ name: String) -> [Person] {
        allPeople().filter { p in p.occasions.contains { $0.type == .custom && CustomHolidays.sameName($0.partnerName ?? "", name) } }
    }

    /// Adds a part to the end of a plan: not started, from You.
    @discardableResult
    func addPart(to m: Moment, kind: ActKind, label: String?) -> Act {
        let act = PlanStore.addPart(to: m, kind: kind, label: label, in: context)
        commit()
        return act
    }

    func setOwners(_ act: Act, _ ids: [UUID]) {
        PlanStore.setOwners(act, to: ids)
        commit()
    }

    /// What an item is, in the user's words ("Silk painting kit"). Empty goes back to the kind's own name.
    func setLabel(_ act: Act, _ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        act.label = trimmed.isEmpty ? nil : trimmed
        commit()
    }

    /// Takes one part out of a plan for good (feedback on build 1019). The rest of the plan, and the day, stay.
    func removePart(_ act: Act) {
        guard act.role == .plan else { return }
        let moment = act.moment
        context.delete(act)
        if let moment { PlanStore.syncStatus(moment) }
        commit()
    }

    func setNote(_ act: Act, _ text: String) {
        PlanStore.setNote(act, to: text)
        commit()
    }

    func completePlan(_ m: Moment, how: ConfirmedBy = .user) {
        PlanStore.completePlan(m, how: how)
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

    /// A card for a reason (story 2.8) goes in the person's yearly record as one line: "Get-well card, Nov 21".
    func recordCard(_ person: Person, reason: CardReason, cardImage: UIImage? = nil, now: Date = Date()) {
        let entry = LedgerEntry(year: Calendar.current.component(.year, from: now), type: .event,
                                what: reason.recordLine(on: now), photoFile: nil, line: reason.recordLine(on: now),
                                personName: person.name, momentID: nil)
        entry.cardFile = cardImage.flatMap { PhotoStore.save($0, maxSide: 2100) }
        context.insert(entry)
        entry.person = person
        commit()
    }

    /// E1: adds the year to the person's ledger.
    func record(_ m: Moment, line: String?) {
        guard let person = m.person else { return }
        if person.ledger.contains(where: { $0.momentID == m.id }) { return }
        let photo = m.actsInOrder.compactMap(\.photoFile).first
        let entry = LedgerEntry(year: m.year, type: m.occasion?.type ?? .birthday, what: MomentEngine.whatWasDone(m),
                                photoFile: photo, line: line?.trimmingCharacters(in: .whitespaces).nilIfEmpty,
                                personName: person.name, momentID: m.id)
        entry.cardFile = m.actsInOrder.compactMap(\.cardFile).first
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
        if url.scheme == "helddear", url.host() == "holiday",
           let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let raw = items.first(where: { $0.name == "raw" })?.value, HolidayRef(raw: raw) != nil,
           let year = items.first(where: { $0.name == "year" })?.value.flatMap(Int.init) {
            route = .holiday(raw, year)
            return
        }
        guard url.scheme == "helddear", url.host() == "moment",
              let idString = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value,
              let id = UUID(uuidString: idString) else { return }
        route = .moment(id, .auto)
    }

    // MARK: Snapshots for the share extension and widget

    /// One day as the widgets show it.
    private func widgetEntry(_ m: Moment, now: Date) -> WidgetSnapshot.Entry? {
        let days = OccasionDates.daysBetween(now, m.dueDate)
        if m.type.kind == .holiday {
            let ref = HolidayRef(type: m.type, name: m.occasion?.partnerName)
            let members = holidayMembers(ref: ref, year: m.year)
            let parts = members.flatMap(\.planParts)
            return WidgetSnapshot.Entry(momentID: m.id, name: ref.label, occasion: ref.label, dueDate: m.dueDate,
                                        detail: nil, soonLine: nil, holidayRaw: ref.raw, year: m.year,
                                        ready: parts.filter(\.isReady).count, total: parts.count, people: members.count)
        }
        guard let p = m.person else { return nil }
        let detail = m.countLine.map { $0.prefix(1).lowercased() + $0.dropFirst() }
        var soon: String?
        if days <= 3 {
            let weekday = m.dueDate.formatted(.dateTime.weekday(.wide))
            switch NextAct.make(state(for: m), now: now) {
            case .orderBy: soon = "Order today"
            case .mailBy: soon = "Mail the card today"
            default: soon = days == 0 ? "Message ready today" : "Message ready \(weekday)"
            }
        }
        let parts = m.planParts
        let nudge = m.planNudge
        return WidgetSnapshot.Entry(momentID: m.id, name: p.name, occasion: m.label, dueDate: m.dueDate, detail: detail,
                                    soonLine: soon, personID: p.id, ready: parts.filter(\.isReady).count, total: parts.count,
                                    nextStep: nudge.isEnabled && nudge.target != nil ? nudge.buttonTitle : nil)
    }

    func writeSnapshots(now: Date = Date()) {
        let people = allPeople().map { SharedPerson(id: $0.id, name: $0.name, isInner: $0.ring == .inner) }
        AppGroup.write(people, to: AppGroup.peopleURL)
        let today = Calendar.current.startOfDay(for: now)
        // A shared holiday is one entry, like Home (Nov 21, 2026).
        let coming = HolidayCollapse.collapse(MomentEngine.visibleMoments(context, now: now).filter { $0.dueDate >= today })
        let entries = coming.prefix(6).compactMap { m -> WidgetSnapshot.Entry? in widgetEntry(m, now: now) }
        let holidays = coming.filter { $0.type.kind == .holiday }.compactMap { widgetEntry($0, now: now) }
        AppGroup.write(WidgetSnapshot(next: Array(entries), writtenAt: now, holidays: holidays), to: AppGroup.widgetURL)
        let people = entries.compactMap(\.personID).compactMap { id in allPeople().first { $0.id == id } }
        Task { @MainActor in
            for p in people {
                guard let image = await FaceFinder.shared.portrait(for: p, side: 160) else { continue }
                try? image.jpegData(compressionQuality: 0.8)?.write(to: AppGroup.faceURL(p.id), options: .atomic)
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
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
