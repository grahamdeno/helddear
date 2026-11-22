import SwiftUI
import UIKit

/// Home (Horizon): one composed screen. The featured person is the one big thing, their name very large in the
/// display serif, one sentence of context and one action. Below, time runs left to right: a band with everyone
/// coming up, placed on a line by date. Tap a name on the line to feature that person.
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var addingFromContacts = false
    @State private var selectedID: UUID?
    /// Home's medallion, on by default; test builds can switch it off in You (AppFeatures.homeMedallion).
    @AppStorage(AppFeatures.homeMedallionKey) private var medallionOn = true

    var body: some View {
        NavigationStack(path: $model.navPath) {
            content
                .background(Brand.page.ignoresSafeArea())
                .toolbar {
                    // You in the top right; Add lives on the timeline (approved Nov 21, 2026).
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { model.route = .settings } label: { YouCircle() }
                            .buttonStyle(.plain)
                            .accessibilityLabel("You and settings")
                    }
                    .sharedBackgroundVisibility(.hidden)
                    // A way back to whoever needs you, when you've moved to someone else (Nov 21, 2026).
                    ToolbarItem(placement: .topBarLeading) { needsYouChip }
                        .sharedBackgroundVisibility(.hidden)
                }
                .tint(Brand.ink)
                .addFromContacts(isPresented: $addingFromContacts)
                .navigationDestination(for: Nav.self) { nav in
                    NavPage(nav: nav)
                }
        }
    }

    @ViewBuilder private var content: some View {
        let _ = model.revision
        let now = Date()
        let allVisible = MomentEngine.visibleMoments(model.context, now: now)
        // A shared holiday is one event on Home, not a row per person (roadmap 1.1).
        let moments = HolidayCollapse.collapse(allVisible)
        let states = moments.map(model.state(for:))
        let heroState = HeroPicker.pick(states, now: now)
        let featured = moments.first { $0.id == selectedID } ?? heroState.flatMap { s in moments.first { $0.id == s.id } }

        if let featured {
            // The featured day is pinned to the top, not centered, so its name stays in one place as you slide
            // through people with more or less under their name (feedback on build 1013).
            VStack(spacing: 0) {
                // The featured days are pages: swipe the big text left or right and the next or previous day slides
                // in, in timeline order, and the timeline follows (feedback on build 1015).
                let line = pagedLine(moments, featured: featured, now: now)
                TabView(selection: Binding(get: { featured.id }, set: { selectedID = $0 })) {
                    ForEach(line, id: \.id) { m in
                        // Home never scrolls (feedback on build 1026), and everyone keeps the medallion (feedback on
                        // build 1027, where dropping it to fit left most people without one). The page keeps its
                        // natural size and is scaled down only by what it lacks.
                        ShrinkToFit { page(m, now: now, medallionSize: medallionOn ? 110 : 0) }
                            .frame(maxHeight: .infinity, alignment: .top)
                        .tag(m.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Raised 40 points into the empty space under the bar (Graham, Nov 21, 2026). The bar is clear here and
                // its only item, the You circle, sits at the right, so nothing overlaps the centered date.
                .padding(.top, -40)
                .accessibilityAction(named: "Next day") { step(1, from: featured, in: moments, now: now) }
                .accessibilityAction(named: "Previous day") { step(-1, from: featured, in: moments, now: now) }
                Spacer(minLength: Brand.space4)
                HorizonBand(moments: moments.filter { $0.dueDate >= Calendar.current.startOfDay(for: now) },
                            selectedID: featured.id, now: now, seasons: model.seasons(now: now),
                            addFromContacts: { addingFromContacts = true }) { selectedID = $0 }
            }
        } else {
            emptyState
        }
    }

    /// The days you can swipe between, in timeline order. The featured day is always one of them, even when it's a
    /// day that has just passed.
    private func pagedLine(_ moments: [Moment], featured: Moment, now: Date) -> [Moment] {
        var line = moments.filter { $0.dueDate >= Calendar.current.startOfDay(for: now) }.sorted { $0.dueDate < $1.dueDate }
        if !line.contains(where: { $0.id == featured.id }) { line.insert(featured, at: 0) }
        return line
    }

    /// One featured page. With a medallion size, the face (or mark) sits between the date and the name; with none,
    /// the small circle above the date (when `circle`), or nothing.
    @ViewBuilder private func page(_ m: Moment, now: Date, medallionSize: CGFloat, circle: Bool = true) -> some View {
        VStack(spacing: Brand.space2) {
            if medallionSize == 0 && circle { topCircle(m) }
            featuredView(m, now: now)
                .environment(\.featuredMedallion, medallionSize > 0 ? AnyView(medallion(m, size: medallionSize)) : nil)
                .environment(\.featuredMedallionSize, medallionSize)
        }
        .padding(.horizontal, Brand.space5)
    }

    /// The medallion: the face (warm-toned, fading into the page at the bottom) or the holiday's mark, between the
    /// date and the name.
    /// A ring around it fills in oxblood as the plan gets ready, in place of the bar (approved Nov 21, 2026).
    @ViewBuilder private func medallion(_ m: Moment, size: CGFloat) -> some View {
        let parts = m.type.kind == .holiday
            ? model.holidayMembers(ref: HolidayRef(type: m.type, name: m.occasion?.partnerName), year: m.year).flatMap(\.planParts)
            : m.planParts
        let ready = parts.filter(\.isReady).count
        if m.type.kind == .holiday {
            ReadyRing(ready: ready, total: parts.count, size: size * 0.87) {
                HolidayMark(type: m.type, name: m.occasion?.partnerName, size: size * 0.87)
            }
            .padding(.bottom, size * 0.13)
        } else if let person = m.person, let partner = model.pairPartner(for: m) {
            Button { model.push(.person(person.id, focus: nil)) } label: {
                PairPortrait(person: person, partner: partner, size: size * 0.86, toned: true, fadeBottom: true,
                             ring: (ready, parts.count))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens \(DisplayName.plain(person.name))'s page")
        } else if let person = m.person {
            Button { model.push(.person(person.id, focus: nil)) } label: {
                ReadyRing(ready: ready, total: parts.count, size: size) {
                    PersonPortrait(person: person, size: size, toned: true, fadeBottom: true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(DisplayName.plain(person.name))'s page")
        }
    }

    @ViewBuilder private func topCircle(_ m: Moment) -> some View {
        if m.type.kind == .holiday {
            HolidayMark(type: m.type, name: m.occasion?.partnerName, size: 40)
        } else if let person = m.person, let partner = model.pairPartner(for: m) {
            Button { model.push(.person(person.id, focus: nil)) } label: { PairPortrait(person: person, partner: partner, size: 34) }
                .buttonStyle(.plain)
        } else if let person = m.person {
            Button { model.push(.person(person.id, focus: nil)) } label: { PersonPortrait(person: person, size: 40) }
                .buttonStyle(.plain)
                .accessibilityLabel("\(DisplayName.plain(person.name))'s page")
        } else {
            Color.clear.frame(width: 40, height: 40)
        }
    }

    @ViewBuilder private func featuredView(_ m: Moment, now: Date) -> some View {
        if m.type.kind == .holiday {
            HolidayFeaturedView(ref: HolidayRef(type: m.type, name: m.occasion?.partnerName),
                                members: model.holidayMembers(ref: HolidayRef(type: m.type, name: m.occasion?.partnerName), year: m.year), now: now)
        } else {
            FeaturedView(moment: m, state: model.state(for: m), now: now,
                         openPerson: { if let p = m.person { model.push(.person(p.id, focus: m.id)) } })
        }
    }

    /// The next or previous day on the timeline, in date order.
    private func step(_ by: Int, from featured: Moment, in moments: [Moment], now: Date) {
        let line = moments.filter { $0.dueDate >= Calendar.current.startOfDay(for: now) }.sorted { $0.dueDate < $1.dueDate }
        guard let i = line.firstIndex(where: { $0.id == featured.id }) else { return }
        let j = i + by
        guard line.indices.contains(j) else { return }
        withAnimation(.snappy) { selectedID = line[j].id }
    }

    /// The people (not shared holidays) with a step due now, soonest first, other than the one on screen.
    private func waiting(now: Date) -> [Moment] {
        let moments = HolidayCollapse.collapse(MomentEngine.visibleMoments(model.context, now: now))
        let states = moments.map(model.state(for:))
        let hero = HeroPicker.pick(states, now: now).flatMap { s in moments.first { $0.id == s.id } }
        let shownID = selectedID ?? hero?.id
        return moments
            .filter { $0.id != shownID && $0.type.kind != .holiday && MomentEngine.needsAction($0, now: now) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    /// "‹ Ana needs you · Dec 17", top left, only when someone else needs you. One tap goes back to them.
    @ViewBuilder private var needsYouChip: some View {
        let _ = model.revision
        let now = Date()
        let list = waiting(now: now)
        if let first = list.first, let person = first.person {
            let name = DisplayName.plain(person.name)
            let words = list.count == 1 ? "\(name) needs you · \(first.dueDate.formatted(.dateTime.month(.abbreviated).day()))"
                : "\(name) and \(list.count - 1) \(list.count == 2 ? "other" : "others") need you"
            Button { withAnimation(.snappy) { selectedID = first.id } } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.caption.weight(.bold)).foregroundStyle(Brand.action)
                    PersonPortrait(person: person, size: 22)
                    Text(words).font(.footnote.weight(.medium)).foregroundStyle(Brand.ink).lineLimit(1)
                }
                .padding(.leading, 8).padding(.trailing, 12)
                .frame(minHeight: 36)
                .background(Brand.card, in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Back to \(name), who needs you, \(OccasionDates.longDate(first.dueDate))")
        }
    }

    private var emptyState: some View {
        VStack(spacing: Brand.space4) {
            Spacer()
            Text("Who do you keep remembered?").font(Brand.display(48)).foregroundStyle(Brand.ink)
                .multilineTextAlignment(.center)
            Text("Add the people whose days matter. Held Dear does the remembering.")
                .font(Brand.serif(19, italic: true)).foregroundStyle(Brand.inkSoft).multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(title: "Add from Contacts") { addingFromContacts = true }
            SecondaryButton(title: "Add someone") { model.route = .addBirthday("") }
            if ContactsService.shared.access == .denied {
                TextLink(title: "Let Held Dear see your contacts in Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
        }
        .padding(.horizontal, Brand.space5)
        .padding(.bottom, Brand.space4)
    }
}

// MARK: Featured person

struct FeaturedView: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    let state: MomentState
    let now: Date
    var openPerson: () -> Void

    var body: some View {
        let name = DisplayName.plain(moment.person?.name ?? "")
        let act = NextAct.make(state, now: now)
        let days = OccasionDates.daysBetween(now, moment.dueDate)
        let missed = state.status == .missed

        FeaturedSlots(
            eyebrow: missed ? "Yesterday" : moment.dueDate.formatted(.dateTime.weekday(.wide).month(.wide).day()),
            title: displayName, open: openPerson, openHint: "Opens \(name)'s page",
            subline: subline(days: days, missed: missed),
            progress: progress, status: statusLine(act: act, name: name)
        ) {
            mainButton(act: act, missed: missed, name: name)
        } link: {
            linkLine(act: act, days: days, missed: missed, name: name)
        }
    }

    /// Planning, ideas and "all set" need no button on Home; a call, a message or a way back does.
    static func hasActionNow(_ act: NextAct) -> Bool {
        switch act {
        case .allSet, .openPlan, .pick, .saveWish: return false
        default: return true
        }
    }

    /// One segment per plan part, for the readiness bar. Empty when there's no plan.
    private var progress: [PartSteps.Progress] {
        moment.planParts.map { PartSteps.progress(step: $0.currentStep ?? "open", family: PartSteps.family(forKindRaw: $0.kindRaw)) }
    }

    /// The one line beside the readiness bar.
    private func statusLine(act: NextAct, name: String) -> String {
        switch act {
        case .allSet: return state.isPlanMoment ? "Everything for \(name) is ready." : plannedLine(name: name)
        case .openPlan(let ready, let total): return "\(ready) of \(total) ready"
        case .pick where GiftTiming.isIdeaTime(due: moment.dueDate, now: now): return ideaLine(name: name)
        case .pick, .saveWish: return nextDayLine(name: name) ?? "Nothing to do yet."
        default:
            let p = progress
            return p.isEmpty ? "" : "\(p.filter { $0 == .ready }.count) of \(p.count) ready"
        }
    }

    /// With nothing to do for this day, the person's next other day, like a shared Christmas (Graham, Nov 21, 2026).
    private func nextDayLine(name: String) -> String? {
        guard let person = moment.person else { return nil }
        let today = Calendar.current.startOfDay(for: now)
        guard let next = person.occasions.flatMap(\.moments)
            .filter({ $0.id != moment.id && $0.dueDate >= today })
            .min(by: { $0.dueDate < $1.dueDate }) else { return nil }
        let parts = next.type.kind == .holiday
            ? model.holidayMembers(ref: HolidayRef(type: next.type, name: next.occasion?.partnerName), year: next.year).flatMap(\.planParts)
            : next.planParts
        var line = "\(next.dueDate < moment.dueDate ? "First" : "Next") for \(name): \(next.label), \(next.dueDate.formatted(.dateTime.month(.abbreviated).day()))"
        if !parts.isEmpty { line += " · \(parts.filter(\.isReady).count) of \(parts.count) ready" }
        return line + "."
    }

    /// The main button: always in the same place. It's the next real thing to do.
    @ViewBuilder private func mainButton(act: NextAct, missed: Bool, name: String) -> some View {
        switch act {
        case .allSet:
            SecondaryButton(title: "Change the plan") {
                model.route = state.isPlanMoment ? .plan(moment.id) : .moment(moment.id, .choose)
            }
        case .openPlan:
            let nudge = moment.planNudge
            let parts = moment.planParts
            if nudge.isEnabled, let t = nudge.target, parts.indices.contains(t) {
                let target = parts[t].id
                PrimaryButton(title: nudge.buttonTitle) { model.push(.item(target)) }
            } else {
                PrimaryButton(title: "See \(name)'s plan") { openPerson() }
            }
        case .pick where GiftTiming.isIdeaTime(due: moment.dueDate, now: now):
            PrimaryButton(title: "See ideas for \(name)") { model.route = .ideas(moment.id) }
        case .pick, .saveWish:
            SecondaryButton(title: "See ideas for \(name)") { model.route = .ideas(moment.id) }
        default:
            PrimaryButton(title: act.title(name: name)) { tap(act) }
        }
    }

    /// One quiet link under the button, or nothing. It never moves the button.
    @ViewBuilder private func linkLine(act: NextAct, days: Int, missed: Bool, name: String) -> some View {
        switch act {
        case .openPlan:
            // The button stays; the "order by" line under it came off (Graham, Nov 21, 2026: one of the two, not both).
            Color.clear
        case .allSet, .pick, .saveWish:
            Color.clear
        default:
            secondary(days: days, missed: missed, name: name)
        }
    }

    private func plannedLine(name: String) -> String {
        guard let plan = moment.plan else { return "\(name)'s day is planned." }
        if let arrives = plan.arrivesBy {
            return "\(plan.title ?? "The gift") is ordered. It arrives by \(arrives.formatted(.dateTime.month(.wide).day()))."
        }
        switch plan.kind {
        case .gift: return "\(plan.title ?? "The gift") is taken care of."
        case .stocking: return "The stocking is taken care of."
        case .fromSanta: return "Santa's gift is taken care of."
        case .cake: return "The cake is taken care of."
        case .flowers: return "The flowers are taken care of."
        case .theDay:
            return "\(PartSteps.displayName(kindRaw: plan.kindRaw, label: plan.label, title: plan.title)) is planned."
        case .kidsMade:
            return "\(PartSteps.displayName(kindRaw: plan.kindRaw, label: plan.label, title: plan.title)) is taken care of."
        case .card: return "The card is on its way."
        case .dinner: return "Dinner is on your calendar."
        case .call: return "You'll call \(name) on the day."
        case .message: return "A message is ready for the day."
        case .other: return "\(plan.title ?? "The plan") is taken care of."
        }
    }

    private func ideaLine(name: String) -> String {
        let saved = GiftTiming.savedThisYear(moment.person?.openWishes.map(\.capturedAt) ?? [], now: now)
        let shelf = saved == 0 ? "" : (saved == 1 ? " You saved 1 idea this year." : " You saved \(saved) ideas this year.")
        return "Time to find something.\(shelf)"
    }

    private var displayName: String {
        let name = DisplayName.plain(moment.person?.name ?? "")
        if moment.type == .anniversary, let partner = moment.occasion?.partnerName { return "\(name) & \(partner)" }
        return name
    }

    private func subline(days: Int, missed: Bool) -> String {
        if missed { return "A late note still counts." }
        let what = moment.countLine.map { $0.prefix(1).lowercased() + $0.dropFirst() } ?? moment.label.lowercased()
        let when: String
        switch days {
        case 0: when = "today"
        case 1: when = "tomorrow"
        default: when = OccasionDates.countdown(to: moment.dueDate, from: now)
        }
        if moment.type.kind == .holiday { return "\(moment.type.title(partner: moment.occasion?.partnerName)), \(when)" }
        return "\(what), \(when)"
    }

    /// One quiet second option: the card, or the family page on the day.
    @ViewBuilder private func secondary(days: Int, missed: Bool, name: String) -> some View {
        if days == 0, let gift = moment.familyGiftURL.flatMap(URL.init(string:)) {
            ShareLink(item: gift, message: Text(moment.type.greeting(name: name))) {
                Text("Send \(name) the family page").font(.callout.weight(.semibold)).foregroundStyle(Brand.action)
                    .frame(minHeight: 44)
            }
        } else if !missed && days >= 6 && AppFeatures.mailedCards {
            TextLink(title: "Or mail \(name) a card") { model.route = .moment(moment.id, .mailCard) }
        } else if !missed && days > 0 && !state.greetingDone {
            TextLink(title: "Or make \(name) a card") { model.route = .moment(moment.id, .photo) }
        }
    }

    private func tap(_ act: NextAct) {
        switch act {
        case .lateNote: model.route = .moment(moment.id, .missed)
        case .dayOfCall:
            if !model.startCall(moment) { model.route = .moment(moment.id, .photo) }
        case .dayOfMessage: model.route = .moment(moment.id, model.phone(for: moment.person) == nil ? .dayOf : .photo)
        case .pick: model.route = .moment(moment.id, .choose)
        case .saveWish: model.route = .addWish(moment.person?.id)
        case .openPlan: model.route = .plan(moment.id)
        default: model.route = .moment(moment.id, .nextStep)
        }
    }
}

// MARK: The horizon band

/// The year ahead as a line. Months are laid out left to right; each person is a mark rising from the line to
/// their name. Slide to move through the year. The featured person is drawn in oxblood.
struct HorizonBand: View {
    @EnvironmentObject var model: AppModel
    let moments: [Moment]
    let selectedID: UUID
    let now: Date
    let seasons: [Season]
    var addFromContacts: () -> Void = {}
    var select: (UUID) -> Void

    @State private var position = ScrollPosition(x: 0)
    @State private var userScrolling = false

    static let monthWidth: CGFloat = 118
    static let lead: CGFloat = 24
    static let axisY: CGFloat = 150
    private static let levels: [CGFloat] = [96, 50, 74, 28]

    var body: some View {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let months = (0..<12).map { cal.date(byAdding: .month, value: $0, to: start)! }
        let marks = layout(start: start)

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Coming up").textStyle(.eyebrow)
                if let season = seasons.first(where: { OccasionDates.daysBetween(now, $0.monthStart) <= 56 }) {
                    Button { model.route = .season(season.monthStart) } label: {
                        Text("· \(season.monthStart.formatted(.dateTime.month(.wide))) is busy").textStyle(.eyebrow, color: Brand.action)
                            .frame(minHeight: 44)
                    }
                }
                Spacer()
                // A menu opens right at the button, on the system's readable material (the centered dialog
                // floated far above it and read poorly over the page, Nov 21).
                Menu {
                    Button { model.route = .addBirthday("") } label: { Label("Someone", systemImage: "person.badge.plus") }
                    Button(action: addFromContacts) { Label("Someone from Contacts", systemImage: "person.crop.circle") }
                    Button { model.route = .addWish(nil) } label: { Label("An idea", systemImage: "gift") }
                } label: {
                    Text("+ Add").font(.callout.weight(.semibold)).foregroundStyle(Brand.action)
                        .frame(minHeight: 44)
                }
                .menuOrder(.fixed)
                .accessibilityLabel("Add")
                .padding(.trailing, Brand.space4)
                Button { model.push(.people) } label: {
                    Text("Everyone ›").font(.callout.weight(.semibold)).foregroundStyle(Brand.action)
                        .frame(minHeight: 44)
                }
                .accessibilityLabel("Everyone")
                .accessibilityHint("Opens everyone, and saved ideas")
            }
            .padding(.horizontal, Brand.space5)
            .padding(.top, Brand.space2)

            GeometryReader { geo in
                let half = geo.size.width / 2
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        Color.clear.frame(width: half)
                        ZStack(alignment: .topLeading) {
                            Rectangle().fill(Brand.ink).frame(width: Self.lead * 2 + Self.monthWidth * 12, height: 1.5)
                                .offset(y: Self.axisY)
                            ForEach(Array(months.enumerated()), id: \.offset) { i, month in
                                Text(month.formatted(.dateTime.month(.abbreviated)))
                                    .font(.caption.weight(.semibold)).foregroundStyle(Brand.inkMuted)
                                    .offset(x: Self.lead + CGFloat(i) * Self.monthWidth, y: Self.axisY + 10)
                                Rectangle().fill(Brand.ink).frame(width: 1.5, height: 10)
                                    .offset(x: Self.lead + CGFloat(i) * Self.monthWidth, y: Self.axisY - 10)
                            }
                            Circle().fill(Brand.ink).frame(width: 7, height: 7)
                                .offset(x: x(for: now, start: start) - 3.5, y: Self.axisY - 3)
                                .accessibilityHidden(true)
                            ForEach(marks, id: \.moment.id) { mark in markView(mark) }
                        }
                        .frame(width: Self.lead * 2 + Self.monthWidth * 12, height: Self.axisY + 34, alignment: .topLeading)
                        Color.clear.frame(width: half)
                    }
                }
                .scrollPosition($position)
                .scrollClipDisabled()
                // The point under the center marker is contentOffset.x in line coordinates (the half-width pads
                // make it so). Whoever is nearest it is featured above, so the name follows the slide.
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, center in
                    guard userScrolling, let nearest = marks.min(by: { abs($0.x - center) < abs($1.x - center) }),
                          nearest.moment.id != selectedID else { return }
                    select(nearest.moment.id)
                }
                .onScrollPhaseChange { _, phase in
                    userScrolling = phase == .interacting || phase == .decelerating
                    // When the slide settles, line the featured person up with the marker.
                    if phase == .idle, let m = marks.first(where: { $0.moment.id == selectedID }) {
                        withAnimation(.snappy) { position.scrollTo(x: m.x) }
                    }
                }
                .onAppear {
                    if let m = marks.first(where: { $0.moment.id == selectedID }) { position.scrollTo(x: m.x) }
                }
                .onChange(of: selectedID) { _, id in
                    guard !userScrolling, let m = marks.first(where: { $0.moment.id == id }) else { return }
                    withAnimation(.snappy) { position.scrollTo(x: m.x) }
                }
                .overlay(alignment: .topLeading) {
                    Rectangle().fill(Brand.action.opacity(0.25)).frame(width: 1, height: Self.axisY)
                        .offset(x: half - 0.5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: Self.axisY + 34)
            .sensoryFeedback(.selection, trigger: selectedID)
        }
        .padding(.bottom, Brand.space2)
        .background(Brand.card.ignoresSafeArea(edges: .bottom))
    }

    private struct Mark {
        let moment: Moment
        let x: CGFloat
        let top: CGFloat
        var leftLabel = false
        /// The wording that fit; nil when the name dropped and only the line shows.
        var text: String?
    }

    /// A name's width as drawn: the text serif, larger when selected, at the reader's text size.
    private func measure(_ text: String, selected: Bool) -> CGFloat {
        let size = UIFontMetrics(forTextStyle: .callout).scaledValue(for: selected ? 20 : 16)
        let font = UIFont(name: TypeStyle.hasSerif ? TypeStyle.textRegular : "", size: size) ?? .systemFont(ofSize: size)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width) + 2
    }

    private func x(for date: Date, start: Date) -> CGFloat {
        let cal = Calendar.current
        let monthIndex = cal.dateComponents([.month], from: start, to: cal.date(from: cal.dateComponents([.year, .month], from: date))!).month ?? 0
        let day = cal.component(.day, from: date)
        let daysInMonth = cal.range(of: .day, in: .month, for: date)?.count ?? 30
        return Self.lead + (CGFloat(monthIndex) + CGFloat(day - 1) / CGFloat(daysInMonth)) * Self.monthWidth
    }

    /// Names placed so none touch and no line crosses a name (BandLayout); shorter wording, then just the line,
    /// when a stretch is crowded. Laid out again when the selection changes, since the selected name is larger.
    private func layout(start: Date) -> [Mark] {
        let shown = moments.sorted(by: { $0.dueDate < $1.dueDate })
            .map { (m: $0, x: x(for: $0.dueDate, start: start)) }
            .filter { $0.x < Self.lead + Self.monthWidth * 12 }
        let wordings = shown.map { labels($0.m) }
        let items = zip(shown, wordings).map { s, words in
            BandLayout.Item(x: s.x, widths: words.map { measure($0, selected: s.m.id == selectedID) })
        }
        let placed = BandLayout.place(items, tops: Self.levels)
        return zip(shown.indices, placed).map { i, p in
            Mark(moment: shown[i].m, x: shown[i].x, top: p.level.map { Self.levels[$0] } ?? (Self.levels.max() ?? 96),
                 leftLabel: p.left, text: p.level == nil ? nil : wordings[i][p.option])
        }
    }

    /// The full wording, then shorter ones: "Ana & M.", a holiday's first word.
    private func labels(_ m: Moment) -> [String] {
        let full = label(m)
        var out = [full]
        if m.type == .anniversary, let p = m.occasion?.partnerName, let first = p.first {
            out.append("\(DisplayName.plain(m.person?.name ?? "")) & \(first).")
        } else if let firstWord = full.split(separator: " ").first, firstWord.count < full.count {
            out.append(String(firstWord))
        }
        return out
    }

    private func label(_ m: Moment) -> String {
        if m.type.kind == .holiday { return m.type.title(partner: m.occasion?.partnerName) }
        let name = DisplayName.plain(m.person?.name ?? "")
        if m.type == .anniversary, let p = m.occasion?.partnerName { return "\(name) & \(p)" }
        return name
    }

    private func markView(_ mark: Mark) -> some View {
        let selected = mark.moment.id == selectedID
        let color = selected ? Brand.action : Brand.ink
        return Button {
            select(mark.moment.id)
            withAnimation(.snappy) { position.scrollTo(x: mark.x) }
        } label: {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(selected ? Brand.action : Brand.inkMuted)
                    .frame(width: selected ? 2 : 1.5, height: Self.axisY - mark.top - 20)
                    .offset(x: 0, y: 22)
                if selected {
                    Circle().fill(Brand.action).frame(width: 12, height: 12)
                        .offset(x: -5, y: Self.axisY - mark.top - 6)
                }
                if let text = mark.text {
                    let w = measure(text, selected: selected)
                    Text(text)
                        .font(Brand.serif(selected ? 20 : 16, relativeTo: .callout))
                        .foregroundStyle(color)
                        .fixedSize()
                        .frame(width: w, alignment: mark.leftLabel ? .trailing : .leading)
                        .offset(x: mark.leftLabel ? -w - BandLayout.inset : BandLayout.inset, y: 0)
                }
            }
            .frame(width: 80, height: Self.axisY - mark.top + 8, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: mark.x, y: mark.top)
        .accessibilityLabel("\(label(mark.moment)), \(OccasionDates.longDate(mark.moment.dueDate))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A large photo of the person: their newest photo in Held Dear, else their contact photo, else a serif initial.
struct HeroPhoto: View {
    let person: Person
    var height: CGFloat = 300

    var body: some View {
        let image = PhotoStore.load(person.photoFiles.last) ?? ContactsService.shared.photo(contactID: person.contactID)
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Brand.faceFill(for: person.name)
                Text(person.initials).font(Brand.display(height * 0.32)).foregroundStyle(Brand.ink.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
        .accessibilityHidden(true)
    }
}


/// Shared holidays on Home: one moment stands for everyone's (roadmap 1.1). The first one that still needs
/// something stands in; the holiday page shows them all.
enum HolidayCollapse {
    static func collapse(_ moments: [Moment]) -> [Moment] {
        var chosen: [String: Moment] = [:]
        for m in moments {
            guard let key = Holidays.groupKey(type: m.type, year: m.year, partner: m.occasion?.partnerName) else { continue }
            if let current = chosen[key] {
                if current.status.isSettled && !m.status.isSettled { chosen[key] = m }
            } else {
                chosen[key] = m
            }
        }
        return moments.filter { m in
            guard let key = Holidays.groupKey(type: m.type, year: m.year, partner: m.occasion?.partnerName) else { return true }
            return chosen[key]?.id == m.id
        }
    }
}

/// One page pushed from Home, with its back link.
struct NavPage: View {
    @EnvironmentObject var model: AppModel
    let nav: Nav

    var body: some View {
        page.backLink(model.backTitle(for: nav))
    }

    @ViewBuilder private var page: some View {
        switch nav {
        case .person(let id, let focus):
            if let p = model.person(id) { PersonView(person: p, focus: focus) } else { Color.clear }
        case .holiday(let raw, let year):
            if let ref = HolidayRef(raw: raw) { HolidayView(ref: ref, year: year) } else { Color.clear }
        case .people:
            PeopleAndIdeasView()
        case .ideas:
            SavedIdeasView()
        case .item(let id):
            if let act = model.act(id) { ItemView(act: act) } else { Color.clear }
        case .personDetails(let id):
            if let p = model.person(id) { PersonView(person: p, showsDetails: true) } else { Color.clear }
        case .relationship(let id):
            if let p = model.person(id) { RelationshipPage(person: p) } else { Color.clear }
        }
    }
}

/// Home's featured day, laid out in fixed places so nothing moves as you slide from one day to the next (feedback on
/// builds 1013 and 1014): the date line, the name (its size varies, its space doesn't), the line under it, the
/// readiness bar with one line, the main button, and one link. A place with nothing in it stays empty and keeps its
/// height. Every place grows with the text size.
/// A thin ring around Home's medallion: a stone track, filled in oxblood by how much of the plan is ready.
/// No plan, no ring.
struct ReadyRing<Content: View>: View {
    let ready: Int
    let total: Int
    let size: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            content
            if total > 0 {
                Circle().stroke(Brand.line, lineWidth: 3)
                    .frame(width: size + 16, height: size + 16)
                Circle().trim(from: 0, to: CGFloat(min(ready, total)) / CGFloat(total))
                    .stroke(Brand.action, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size + 16, height: size + 16)
            }
        }
        .frame(width: size + 20, height: size + 20)
        .accessibilityElement(children: .combine)
        .accessibilityValue(total > 0 ? "\(ready) of \(total) ready" : "")
    }
}

private struct ShrinkHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Shows a page at its natural height, scaled down only if it doesn't fit, so Home never needs to scroll.
struct ShrinkToFit<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var natural: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let scale = natural > 0 ? min(1, geo.size.height / natural) : 1
            content
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { g in Color.clear.preference(key: ShrinkHeightKey.self, value: g.size.height) })
                .scaleEffect(scale, anchor: .top)
                // Centered in its space when it fits, so it sits evenly on every phone (Nov 21, 2026).
                .frame(width: geo.size.width, height: geo.size.height, alignment: scale < 1 ? .top : .center)
        }
        .onPreferenceChange(ShrinkHeightKey.self) { natural = $0 }
    }
}

private struct FeaturedMedallionSizeKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
private struct FeaturedMedallionKey: EnvironmentKey { static let defaultValue: AnyView? = nil }
extension EnvironmentValues {
    /// Home's medallion, drawn between the date and the name when it's on.
    var featuredMedallionSize: CGFloat {
        get { self[FeaturedMedallionSizeKey.self] }
        set { self[FeaturedMedallionSizeKey.self] = newValue }
    }
    var featuredMedallion: AnyView? {
        get { self[FeaturedMedallionKey.self] }
        set { self[FeaturedMedallionKey.self] = newValue }
    }
}

struct FeaturedSlots<MainButton: View, LinkLine: View>: View {
    @Environment(\.featuredMedallion) private var medallion
    @Environment(\.featuredMedallionSize) private var medallionSize
    let eyebrow: String
    let title: String
    let open: () -> Void
    let openHint: String
    let subline: String
    let progress: [PartSteps.Progress]
    let status: String
    /// Home shows a button only when there's one real thing to do now (a call or message on the day, a way back).
    /// Planning happens on the person's page, which the name and face open (Nov 21, 2026).
    var showsActions = true
    @ViewBuilder var button: MainButton
    @ViewBuilder var link: LinkLine

    @ScaledMetric(relativeTo: .title3) private var sublineHeight: CGFloat = 34
    @ScaledMetric(relativeTo: .callout) private var statusHeight: CGFloat = 54
    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .callout) private var linkHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            Text(eyebrow).textStyle(.eyebrow)
            if let medallion {
                medallion.padding(.top, Brand.space3)
            }
            Button(action: open) {
                // The name opens the page. The › after it came off (Graham, Nov 21, 2026): the face and name are enough.
                Text(title).foregroundColor(Brand.ink)
                    .font(Brand.display(NameSize.featured(title), relativeTo: .largeTitle))
                    .tracking(-2)
                    .lineLimit(NameSize.maxLines).minimumScaleFactor(0.6)
                    .frame(height: NameSize.featuredSlot, alignment: .bottom)
                    .shadow(color: Brand.page.opacity(medallion == nil ? 0 : 0.6), radius: 8)
                    .padding(.top, medallion == nil ? Brand.space3 : -70 * medallionSize / 126 + NameSize.featuredDrop(title))
            }
            .buttonStyle(.plain)
            .zIndex(1)
            .accessibilityHint(openHint)
            Text(subline)
                .font(Brand.display(24, relativeTo: .title3, italic: true)).foregroundStyle(Brand.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(height: sublineHeight)
                .padding(.top, Brand.space2 - (medallion == nil ? 0 : NameSize.featuredDrop(title)))
            VStack(spacing: Brand.space2) {
                // With the medallion, the ring around the face shows this instead.
                if !progress.isEmpty && medallion == nil {
                    HStack(spacing: 4) {
                        ForEach(Array(progress.enumerated()), id: \.offset) { _, p in
                            Rectangle().fill(color(p)).frame(height: 6)
                        }
                    }
                    .frame(maxWidth: 320)
                    .accessibilityHidden(true)
                }
                if !status.isEmpty {
                    Text(status).textStyle(.callout, color: Brand.inkSoft).lineLimit(2).minimumScaleFactor(0.85)
                }
            }
            .frame(height: statusHeight, alignment: .center)
            .padding(.top, Brand.space4)
            if showsActions {
                button
                    .frame(height: buttonHeight)
                    .padding(.top, Brand.space3)
                link
                    .frame(height: linkHeight)
                    .padding(.top, Brand.space2)
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private func color(_ p: PartSteps.Progress) -> Color {
        switch p {
        case .ready: Brand.ink
        case .started: Brand.inkMuted
        case .notStarted: Brand.line
        }
    }
}

/// Your initial in a small outlined circle, top right of Home: it opens You and settings. A plain person outline
/// until you've saved your name.
struct YouCircle: View {
    @AppStorage("yourName") private var yourName = ""

    private var initial: String? {
        let name = yourName.isEmpty ? (MailAddress.saved?.firstName ?? "") : yourName
        return name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() }
    }

    var body: some View {
        ZStack {
            Circle().strokeBorder(Brand.inkMuted, lineWidth: 1)
            if let initial {
                Text(initial).font(Brand.serif(17, relativeTo: .body)).foregroundStyle(Brand.ink)
            } else {
                Image(systemName: "person").font(.system(size: 15)).foregroundStyle(Brand.ink)
            }
        }
        .frame(width: 36, height: 36)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}
