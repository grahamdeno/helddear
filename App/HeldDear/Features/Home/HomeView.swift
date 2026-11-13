import SwiftUI
import UIKit

/// Home (Horizon): one composed screen. The featured person is the one big thing, their name very large in the
/// display serif, one sentence of context and one action. Below, time runs left to right: a band with everyone
/// coming up, placed on a line by date. Tap a name on the line to feature that person.
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var path: [UUID] = []
    @State private var addingFromContacts = false
    @State private var selectedID: UUID?

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(Brand.page.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Text("Held Dear").font(Brand.serif(20, relativeTo: .headline, italic: true)).foregroundStyle(Brand.ink)
                            .accessibilityAddTraits(.isHeader)
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { model.route = .rings } label: { Image(systemName: "person.2") }
                            .accessibilityLabel("Your people")
                        Menu {
                            Button { model.route = .addBirthday("") } label: { Label("Type a birthday", systemImage: "character.cursor.ibeam") }
                            Button { addingFromContacts = true } label: { Label("Add from Contacts", systemImage: "person.crop.circle.badge.plus") }
                            Button { model.route = .addWish(nil) } label: { Label("Save a wish", systemImage: "heart") }
                            Divider()
                            Button { model.route = .settings } label: { Label("Settings", systemImage: "gearshape") }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add")
                    }
                }
                .tint(Brand.ink)
                .addFromContacts(isPresented: $addingFromContacts)
                .navigationDestination(for: UUID.self) { id in
                    if let p = model.person(id) { PersonView(person: p) }
                }
        }
    }

    @ViewBuilder private var content: some View {
        let _ = model.revision
        let now = Date()
        let moments = MomentEngine.visibleMoments(model.context, now: now)
        let states = moments.map(model.state(for:))
        let heroState = HeroPicker.pick(states, now: now)
        let featured = moments.first { $0.id == selectedID } ?? heroState.flatMap { s in moments.first { $0.id == s.id } }

        if let featured {
            VStack(spacing: 0) {
                Spacer(minLength: Brand.space3)
                FeaturedView(moment: featured, state: model.state(for: featured), now: now,
                             openPerson: { if let p = featured.person { path.append(p.id) } })
                    .padding(.horizontal, Brand.space5)
                otherReady(moments, featured: featured, now: now)
                Spacer(minLength: Brand.space4)
                HorizonBand(moments: moments.filter { $0.dueDate >= Calendar.current.startOfDay(for: now) },
                            selectedID: featured.id, now: now, seasons: model.seasons(now: now)) { selectedID = $0 }
            }
        } else {
            emptyState
        }
    }

    /// Others waiting on the user right now, as one quiet line. Tapping features the first.
    @ViewBuilder private func otherReady(_ moments: [Moment], featured: Moment, now: Date) -> some View {
        let ready = moments.filter { $0.id != featured.id && MomentEngine.needsAction($0, now: now) }
        if let first = ready.first {
            let names = ready.prefix(3).compactMap { $0.person?.name }.joined(separator: ", ")
            Button { selectedID = first.id } label: {
                Text("Also ready: \(names)").font(.callout.weight(.medium)).foregroundStyle(Brand.action)
                    .frame(minHeight: 44)
            }
            .padding(.top, Brand.space2)
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
            SecondaryButton(title: "Type a birthday") { model.route = .addBirthday("") }
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
        let name = moment.person?.name ?? ""
        let act = NextAct.make(state, now: now)
        let days = OccasionDates.daysBetween(now, moment.dueDate)
        let missed = state.status == .missed

        VStack(spacing: 0) {
            Text(missed ? "Yesterday" : moment.dueDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .textStyle(.eyebrow)
            Button(action: openPerson) {
                Text(displayName)
                    .font(Brand.display(nameSize, relativeTo: .largeTitle))
                    .tracking(-2)
                    .foregroundStyle(Brand.ink)
                    .lineLimit(1).minimumScaleFactor(0.4)
                    .padding(.top, Brand.space3)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens \(name)'s page")
            Text(subline(days: days, missed: missed))
                .font(Brand.display(24, relativeTo: .title3, italic: true)).foregroundStyle(Brand.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.top, Brand.space2)
            if let wish = moment.person?.openWishes.first, !missed {
                (Text("\(name) mentioned wanting ") + Text(wish.text).italic() + Text("."))
                    .font(Brand.serif(20, relativeTo: .body)).foregroundStyle(Brand.ink)
                    .multilineTextAlignment(.center).lineLimit(3)
                    .frame(maxWidth: 320)
                    .padding(.top, Brand.space6)
            }
            PrimaryButton(title: act.title(name: name)) { tap(act) }
                .padding(.top, Brand.space6)
            secondary(days: days, missed: missed, name: name)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var displayName: String {
        let name = moment.person?.name ?? ""
        if moment.type == .anniversary, let partner = moment.occasion?.partnerName { return "\(name) & \(partner)" }
        return name
    }

    private var nameSize: CGFloat {
        switch displayName.count {
        case ...5: 128
        case 6...8: 100
        default: 76
        }
    }

    private func subline(days: Int, missed: Bool) -> String {
        if missed { return "A late note still counts." }
        let what = moment.countLine.map { $0.prefix(1).lowercased() + $0.dropFirst() } ?? moment.type.label.lowercased()
        let when: String
        switch days {
        case 0: when = "today"
        case 1: when = "tomorrow"
        default: when = OccasionDates.countdown(to: moment.dueDate, from: now)
        }
        if moment.type.kind == .holiday { return "\(moment.type.label), \(when)" }
        return "\(what), \(when)"
    }

    /// One quiet second option: the card, or the family page on the day.
    @ViewBuilder private func secondary(days: Int, missed: Bool, name: String) -> some View {
        if days == 0, let gift = moment.familyGiftURL.flatMap(URL.init(string:)) {
            ShareLink(item: gift, message: Text(moment.type.greeting(name: name))) {
                Text("Send \(name) the family page").font(.callout.weight(.semibold)).foregroundStyle(Brand.action)
                    .frame(minHeight: 44)
            }
            .padding(.top, Brand.space2)
        } else if !missed && days >= 6 {
            TextLink(title: "Or mail \(name) a card") { model.route = .moment(moment.id, .mailCard) }
                .padding(.top, Brand.space2)
        } else if !missed && days > 0 && !state.greetingDone {
            TextLink(title: "Or make \(name) a card") { model.route = .moment(moment.id, .photo) }
                .padding(.top, Brand.space2)
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
    var select: (UUID) -> Void

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
                Spacer()
                if let season = seasons.first(where: { OccasionDates.daysBetween(now, $0.monthStart) <= 56 }) {
                    Button { model.route = .season(season.monthStart) } label: {
                        Text("\(season.monthStart.formatted(.dateTime.month(.wide))) is busy").textStyle(.eyebrow, color: Brand.action)
                            .frame(minHeight: 44)
                    }
                } else {
                    Text("Slide to move").textStyle(.eyebrow)
                }
            }
            .padding(.horizontal, Brand.space5)
            .padding(.top, Brand.space2)

            ScrollView(.horizontal, showsIndicators: false) {
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
            }
            .scrollClipDisabled()
        }
        .padding(.bottom, Brand.space2)
        .background(Brand.card.ignoresSafeArea(edges: .bottom))
    }

    private struct Mark { let moment: Moment; let x: CGFloat; let top: CGFloat }

    private func x(for date: Date, start: Date) -> CGFloat {
        let cal = Calendar.current
        let monthIndex = cal.dateComponents([.month], from: start, to: cal.date(from: cal.dateComponents([.year, .month], from: date))!).month ?? 0
        let day = cal.component(.day, from: date)
        let daysInMonth = cal.range(of: .day, in: .month, for: date)?.count ?? 30
        return Self.lead + (CGFloat(monthIndex) + CGFloat(day - 1) / CGFloat(daysInMonth)) * Self.monthWidth
    }

    /// Stagger labels on a few heights so close dates don't overlap.
    private func layout(start: Date) -> [Mark] {
        var lastX = Array(repeating: -CGFloat.infinity, count: Self.levels.count)
        var out: [Mark] = []
        for m in moments.sorted(by: { $0.dueDate < $1.dueDate }) {
            let mx = x(for: m.dueDate, start: start)
            guard mx < Self.lead + Self.monthWidth * 12 else { continue }
            let level = (0..<Self.levels.count).first { mx - lastX[$0] > 78 } ?? (out.count % Self.levels.count)
            lastX[level] = mx
            out.append(Mark(moment: m, x: mx, top: Self.levels[level]))
        }
        return out
    }

    private func label(_ m: Moment) -> String {
        let name = m.person?.name ?? ""
        if m.type == .anniversary, let p = m.occasion?.partnerName { return "\(name) & \(p)" }
        return name
    }

    private func markView(_ mark: Mark) -> some View {
        let selected = mark.moment.id == selectedID
        let color = selected ? Brand.action : Brand.ink
        return Button { select(mark.moment.id) } label: {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(selected ? Brand.action : Brand.inkMuted)
                    .frame(width: selected ? 2 : 1.5, height: Self.axisY - mark.top - 20)
                    .offset(x: 0, y: 22)
                if selected {
                    Circle().fill(Brand.action).frame(width: 12, height: 12)
                        .offset(x: -5, y: Self.axisY - mark.top - 6)
                }
                Text(label(mark.moment))
                    .font(Brand.serif(selected ? 20 : 16, relativeTo: .callout))
                    .foregroundStyle(color)
                    .fixedSize()
                    .offset(x: 4, y: 0)
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
