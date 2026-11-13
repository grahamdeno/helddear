import SwiftUI
import UIKit

/// Home, ordered by time and never alphabetically: today's date, the next person as the one big thing,
/// anything else that's ready, then the year as a month-by-month timeline of faces.
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var path: [UUID] = []
    @State private var addingFromContacts = false
    @State private var showAllReady = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                content
                    .padding(.horizontal, Brand.space5)
                    .padding(.top, 4)
                    .padding(.bottom, 32)
            }
            .background(Brand.page.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { model.route = .settings } label: {
                        Image(systemName: "gearshape").font(.system(size: 16, weight: .regular))
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { model.route = .rings } label: {
                        Image(systemName: "person.2").font(.system(size: 16, weight: .regular))
                    }
                    .accessibilityLabel("Your people")
                    Menu {
                        Button { model.route = .addBirthday("") } label: { Label("Type a birthday", systemImage: "character.cursor.ibeam") }
                        Button { addingFromContacts = true } label: { Label("Add from Contacts", systemImage: "person.crop.circle.badge.plus") }
                        Button { model.route = .addWish(nil) } label: { Label("Save a wish", systemImage: "heart") }
                    } label: {
                        Image(systemName: "plus").font(.system(size: 18, weight: .regular))
                    }
                    .accessibilityLabel("Add")
                }
            }
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
        let hero = heroState.flatMap { s in moments.first { $0.id == s.id } }
        let ready = moments.filter { $0.id != hero?.id && MomentEngine.needsAction($0, now: now) }

        VStack(alignment: .leading, spacing: Brand.space6) {
            Text(now.formatted(.dateTime.weekday(.wide).month(.wide).day())).textStyle(.eyebrow)
                .padding(.bottom, -Brand.space4)

            if let hero, let state = heroState {
                HeroCard(moment: hero, state: state, now: now)
            } else {
                emptyHero
            }

            if !ready.isEmpty {
                VStack(alignment: .leading, spacing: Brand.space3) {
                    Eyebrow(text: "Ready for you")
                    ForEach(showAllReady ? ready : Array(ready.prefix(2)), id: \.id) { m in readyCard(m, now: now) }
                    if ready.count > 2 && !showAllReady {
                        TextLink(title: "\(ready.count - 2) more ready") { showAllReady = true }
                    }
                }
            }

            if !moments.isEmpty {
                YourYear(moments: moments, now: now, seasons: model.seasons(now: now)) { person in path.append(person.id) }
            }

            if model.firstVisitCardDismissed == false && !moments.isEmpty { firstVisitCard }

            SecondaryButton(title: "Add a birthday") { model.route = .addBirthday("") }
            if ContactsService.shared.access == .denied {
                TextLink(title: "Let Held Dear see your contacts in Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, -Brand.space5)
            }
        }
    }

    private var emptyHero: some View {
        VStack(alignment: .leading, spacing: Brand.space4) {
            CirclesMark(size: 72)
            Text("Who do you keep remembered?").textStyle(.display)
            Text("Add the people whose birthdays matter. Held Dear does the remembering.")
                .textStyle(.body, color: Brand.ink.opacity(0.85))
            PrimaryButton(title: "Add from Contacts") { addingFromContacts = true }
            SecondaryButton(title: "Type a birthday") { model.route = .addBirthday("") }
        }
        .padding(.vertical, Brand.space4)
    }

    /// A next-step card for someone other than the hero.
    private func readyCard(_ m: Moment, now: Date) -> some View {
        let s = model.state(for: m)
        let act = NextAct.make(s, now: now)
        let name = m.person?.name ?? ""
        return OptionRow(title: name, caption: "\(act.title(name: name)) · \(OccasionDates.countdown(to: m.dueDate, from: now))",
                         action: { model.route = .moment(m.id, .auto) },
                         leading: { if let p = m.person { Face(person: p) } },
                         trailing: { ChevronDisc() })
    }

    private var firstVisitCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text("Has anyone mentioned wanting something?").textStyle(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { model.firstVisitCardDismissed = true } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .regular)).foregroundStyle(Brand.inkMuted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Dismiss")
                .padding(.top, -12).padding(.trailing, -12)
            }
            Text("Save it now and it comes back when their birthday is near.").textStyle(.body, color: Brand.ink.opacity(0.85))
            PrimaryButton(title: "Add a wish") {
                model.firstVisitCardDismissed = true
                model.route = .addWish(nil)
            }
        }
        .padding(20)
        .overlay(Rectangle().stroke(Brand.line, lineWidth: 1))
    }
}

// MARK: Hero

/// The next person, quiet and large: their photo, their name in serif, the date, the countdown,
/// the thing they mentioned, then the next act and a card. Direction C (Quiet).
struct HeroCard: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    let state: MomentState
    let now: Date

    var body: some View {
        let person = moment.person
        let name = person?.name ?? ""
        let act = NextAct.make(state, now: now)
        let days = OccasionDates.daysBetween(now, moment.dueDate)

        VStack(alignment: .leading, spacing: Brand.space4) {
            if let person { HeroPhoto(person: person) }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Brand.space1) {
                    if state.status == .missed {
                        Text("Yesterday was \(moment.subject).").textStyle(.title).fixedSize(horizontal: false, vertical: true)
                        Text("A late note still counts.").textStyle(.callout, color: Brand.inkMuted)
                    } else {
                        Text(name).textStyle(.display).lineLimit(2).minimumScaleFactor(0.7)
                        Text(contextLine(days: days)).textStyle(.callout, color: Brand.inkMuted)
                    }
                }
                Spacer(minLength: Brand.space3)
                countdown(days: days)
            }
            if let wish = person?.openWishes.first, state.status != .missed {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mentioned").textStyle(.eyebrow)
                    Text("\u{201C}\(wish.text)\u{201D}").font(Brand.serif(20, relativeTo: .title3, italic: true))
                        .foregroundStyle(Brand.ink).lineLimit(2)
                }
                .padding(.top, Brand.space1)
            }
            Rectangle().fill(Brand.line).frame(height: 1)
            if act.isGentle {
                SecondaryButton(title: act.title(name: name)) { tap(act) }
            } else {
                PrimaryButton(title: act.title(name: name)) { tap(act) }
            }
            if state.status != .missed && days > 0 {
                if days >= 6 {
                    SecondaryButton(title: "Mail \(name) a card") { model.route = .moment(moment.id, .mailCard) }
                } else if !state.greetingDone {
                    SecondaryButton(title: "Make \(name) a card") { model.route = .moment(moment.id, .photo) }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func countdown(days: Int) -> some View {
        if state.status == .missed {
            EmptyView()
        } else if days == 0 {
            Text("Today").font(Brand.countdownFont(44)).foregroundStyle(Brand.accent)
        } else {
            let months = days > NextAct.farDays
            let number = months ? max(1, Int((Double(days) / 30.4).rounded())) : days
            VStack(alignment: .trailing, spacing: -6) {
                Text("\(number)").font(Brand.countdownFont(64)).foregroundStyle(Brand.ink)
                Text(months ? (number == 1 ? "month" : "months") : (number == 1 ? "day" : "days"))
                    .textStyle(.caption, color: Brand.inkMuted)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func contextLine(days: Int) -> String {
        let date = moment.dueDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return days == 0 ? "\(moment.occasionLine) today" : "\(moment.occasionLine) · \(date)"
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

/// A large photo of the person: their newest photo in Held Dear, else their contact photo, else a quiet serif initial.
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
                Text(person.initials).font(Brand.serif(96)).foregroundStyle(Brand.ink.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: Coming up

/// The year ahead as a plain list: month in serif, then one row per person with the day number in serif.
struct YourYear: View {
    let moments: [Moment]
    let now: Date
    let seasons: [Season]
    var openPerson: (Person) -> Void

    var body: some View {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let months = (0..<12).map { cal.date(byAdding: .month, value: $0, to: start)! }
        let upcoming = moments.filter { $0.dueDate >= cal.startOfDay(for: now) }

        VStack(alignment: .leading, spacing: Brand.space5) {
            Text("Coming up").textStyle(.headline)
            ForEach(months, id: \.self) { month in
                let list = items(in: month, from: upcoming)
                if !list.isEmpty { monthBlock(month, list) }
            }
        }
    }

    private func items(in month: Date, from upcoming: [Moment]) -> [Moment] {
        let end = Calendar.current.date(byAdding: .month, value: 1, to: month)!
        return upcoming.filter { $0.dueDate >= month && $0.dueDate < end }.sorted { $0.dueDate < $1.dueDate }
    }

    private func monthBlock(_ month: Date, _ items: [Moment]) -> some View {
        let title = month.formatted(.dateTime.month(.wide))
        return VStack(alignment: .leading, spacing: 0) {
            Text(title).textStyle(.eyebrow).padding(.bottom, Brand.space2)
            Rectangle().fill(Brand.line).frame(height: 1)
            ForEach(items, id: \.id) { m in row(m) }
            busyLine(month, title: title, items: items)
        }
    }

    @ViewBuilder private func row(_ m: Moment) -> some View {
        if let p = m.person {
            Button { openPerson(p) } label: {
                HStack(alignment: .center, spacing: Brand.space4) {
                    Text("\(Calendar.current.component(.day, from: m.dueDate))")
                        .font(Brand.serif(30, relativeTo: .title2)).monospacedDigit()
                        .foregroundStyle(Brand.ink).frame(width: 44, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).textStyle(.bodyStrong).lineLimit(1)
                        Text(caption(m)).textStyle(.caption, color: Brand.inkMuted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Face(person: p, size: 40)
                }
                .padding(.vertical, Brand.space3)
                .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(p.name), \(OccasionDates.longDate(m.dueDate))")
        }
    }

    private func caption(_ m: Moment) -> String {
        let weekday = m.dueDate.formatted(.dateTime.weekday(.wide))
        return "\(m.occasionLine) · \(weekday)"
    }

    /// The busy-month insight, inside its month, only within 8 weeks.
    @ViewBuilder private func busyLine(_ month: Date, title: String, items: [Moment]) -> some View {
        if let season = seasons.first(where: { Calendar.current.isDate($0.monthStart, equalTo: month, toGranularity: .month) }),
           OccasionDates.daysBetween(now, month) <= 56 {
            let cutoff = OccasionDates.adding(days: -OccasionDates.cutoffDays, to: items.first?.dueDate ?? month)
            BusyMonthLine(text: "\(season.momentIDs.count) birthdays to plan in \(title). Do them together by \(OccasionDates.shortDate(cutoff)).",
                          monthStart: season.monthStart)
        }
    }
}

struct BusyMonthLine: View {
    @EnvironmentObject var model: AppModel
    let text: String
    let monthStart: Date

    var body: some View {
        Button { model.route = .season(monthStart) } label: {
            HStack(spacing: Brand.space2) {
                Rectangle().fill(Brand.accent).frame(width: 6, height: 6).accessibilityHidden(true)
                Text(text).textStyle(.callout, color: Brand.action).underline(true, color: Brand.line).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Brand.space2)
        }
        .buttonStyle(.plain)
    }
}
