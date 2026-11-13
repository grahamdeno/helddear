import SwiftUI

/// "Your people": everyone, soonest first. Each row is the person, their next day, and how early Held Dear reminds
/// you (tap that to change it). Replaced the ring diagram, which looked busy and told you little (Nov 12).
struct RingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var sheetPerson: Person?
    @State private var addingFromContacts = false

    var body: some View {
        let _ = model.revision
        let rows = model.allPeople().map { p in (person: p, next: model.nextMoment(for: p)) }
            .sorted { ($0.next?.dueDate ?? .distantFuture) < ($1.next?.dueDate ?? .distantFuture) }
        let early = rows.filter { $0.person.ring == .inner }.count

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your people").textStyle(.title).accessibilityAddTraits(.isHeader)
                Text(summary(total: rows.count, early: early))
                    .font(Brand.serif(18, relativeTo: .callout, italic: true)).foregroundStyle(Brand.inkSoft)
                    .padding(.top, Brand.space1)
                    .padding(.bottom, Brand.space5)
                ForEach(rows, id: \.person.id) { row in
                    personRow(row.person, next: row.next)
                }
                SecondaryButton(title: "Add from Contacts") { addingFromContacts = true }
                    .padding(.top, Brand.space5)
                Text("Tap a person to open them. Tap the reminder on the right to change how early Held Dear tells you.")
                    .textStyle(.caption, color: Brand.inkMuted)
                    .padding(.top, Brand.space3)
            }
            .padding(.horizontal, Brand.space5)
            .padding(.vertical, 8)
        }
        .background(Brand.page.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: UUID.self) { id in
            if let p = model.person(id) { PersonView(person: p) }
        }
        .sheet(item: $sheetPerson) { p in RingSheet(person: p).presentationDetents([.medium]) }
        .addFromContacts(isPresented: $addingFromContacts)
    }

    private func summary(total: Int, early: Int) -> String {
        let people = total == 1 ? "1 person" : "\(total) people"
        guard early > 0 else { return people }
        return "\(people) · \(early) with a 3-week heads-up"
    }

    private func personRow(_ p: Person, next: Moment?) -> some View {
        HStack(alignment: .center, spacing: Brand.space4) {
            NavigationLink(value: p.id) {
                HStack(spacing: Brand.space4) {
                    Text(next.map { String(Calendar.current.component(.day, from: $0.dueDate)) } ?? "–")
                        .font(Brand.display(32, relativeTo: .title2)).monospacedDigit()
                        .foregroundStyle(Brand.ink).frame(width: 46, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).textStyle(.bodyStrong).lineLimit(1)
                        Text(caption(next)).textStyle(.caption, color: Brand.inkMuted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { sheetPerson = p } label: {
                Text(reminder(p.ring)).font(.caption.weight(.semibold)).foregroundStyle(Brand.ink)
                    .padding(.horizontal, 10).frame(minHeight: 32)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reminder for \(p.name): \(p.ring.promise). Change")
        }
        .padding(.vertical, Brand.space2)
    }

    private func caption(_ next: Moment?) -> String {
        guard let next else { return "No date yet" }
        return "\(next.dueDate.formatted(.dateTime.month(.abbreviated).day())) · \(next.occasionLine)"
    }

    private func reminder(_ ring: Ring) -> String {
        switch ring {
        case .inner: "3 weeks"
        case .middle: "1 week"
        case .outer: "On the day"
        }
    }
}

struct EveryoneView: View {
    @EnvironmentObject var model: AppModel
    var focus: Ring
    @State private var search = ""

    var body: some View {
        let _ = model.revision
        let people = model.allPeople().filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.fullName.localizedCaseInsensitiveContains(search) }
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(focus.label).textStyle(.title)
                TextField("Search", text: $search).textStyle(.body)
                    .padding(.horizontal, Brand.space4).frame(minHeight: 48)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
                ForEach([focus] + Ring.allCases.filter { $0 != focus }) { ring in
                    let group = people.filter { $0.ring == ring }
                    if !group.isEmpty {
                        VStack(alignment: .leading, spacing: Brand.space2) {
                            Eyebrow(text: ring.label)
                            ForEach(group, id: \.id) { p in
                                NavigationLink(value: p.id) {
                                    HStack(spacing: 12) {
                                        Face(person: p)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.name).textStyle(.bodyStrong)
                                            if let b = p.birthday {
                                                Text(OccasionDates.longDate(OccasionDates.date(month: b.month, day: b.day, year: 2028)))
                                                    .textStyle(.caption, color: Brand.inkMuted)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        ChevronDisc()
                                    }
                                    .padding(.vertical, Brand.space3).padding(.horizontal, Brand.space4)
                                    .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Brand.space5)
            .padding(.vertical, 8)
        }
        .background(Brand.page.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// S1. Busy season heads-up: plan the month's birthdays together, one person per screen.
struct SeasonView: View {
    @EnvironmentObject var model: AppModel
    let monthStart: Date
    @State private var queue: [UUID] = []
    @State private var index = 0
    @State private var planning = false

    var body: some View {
        if planning, index < queue.count, let m = model.moment(queue[index]) {
            ChooseStep(moment: m) { _ in advance() }
                .id(m.id)
                .transition(.opacity)
        } else {
            overview
        }
    }

    private var monthMoments: [Moment] {
        let cal = Calendar.current
        let end = cal.date(byAdding: .month, value: 1, to: monthStart)!
        return model.allMoments().filter { $0.person != nil && $0.dueDate >= monthStart && $0.dueDate < end && !$0.status.isSettled }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var overview: some View {
        let moments = monthMoments
        let month = monthStart.formatted(.dateTime.month(.wide))
        let toPlan = moments.filter { ($0.occasion?.effectiveRing ?? .outer) != .outer && $0.status == .upcoming }
        return FlowScreen(onClose: { model.route = nil }) {
            Question(tag: "Early heads-up · \(OccasionDates.longDate(Date()))", title: "\(month) is a big month",
                     subtitle: "\(moments.count) of your people have birthdays in it. Planning them together takes about as long as one.",
                     style: .title)
            VStack(spacing: Brand.space2) {
                ForEach(moments, id: \.id) { m in
                    if let p = m.person {
                        OptionRow(title: p.name, caption: caption(m, p), action: { model.route = .moment(m.id, .auto) },
                                  leading: { Face(person: p) },
                                  trailing: { Tag(text: OccasionDates.shortDate(m.dueDate)) })
                    }
                }
            }
        } footer: {
            if toPlan.isEmpty {
                PrimaryButton(title: "OK") { model.route = nil }
            } else {
                PrimaryButton(title: "Plan them together") {
                    queue = toPlan.map(\.id)
                    index = 0
                    withAnimation(.easeOut(duration: 0.22)) { planning = true }
                }
                TextLink(title: "One at a time is fine") { model.route = nil }
            }
        }
    }

    private func caption(_ m: Moment, _ p: Person) -> String {
        let ring = m.occasion?.effectiveRing ?? p.ring
        var text = ring.label
        if let t = m.turning { text += " · turning \(t)" } else if ring == .outer { text += " · message on the day" }
        if m.status == .planning { text += " · planned" }
        return text
    }

    private func advance() {
        withAnimation(.easeOut(duration: 0.22)) {
            if index + 1 < queue.count { index += 1 } else { planning = false; model.route = nil }
        }
    }
}
