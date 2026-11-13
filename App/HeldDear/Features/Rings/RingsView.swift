import SwiftUI

/// R1. "Your people": faces for the inner and middle rings, a count for the outer ring.
struct RingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var sheetPerson: Person?
    @State private var addingFromContacts = false

    private let size: CGFloat = 346

    var body: some View {
        let _ = model.revision
        let people = model.allPeople()
        let inner = people.filter { $0.ring == .inner }
        let middle = people.filter { $0.ring == .middle }
        let outer = people.filter { $0.ring == .outer }

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Your people").textStyle(.title).accessibilityAddTraits(.isHeader)
                diagram(inner: inner, middle: middle, outerCount: outer.count)
                    .frame(maxWidth: .infinity)
                VStack(spacing: Brand.space2) {
                    ringRow(.inner, count: inner.count, fill: Brand.ringInner)
                    ringRow(.middle, count: middle.count, fill: Brand.ringMiddle)
                    ringRow(.outer, count: outer.count, fill: Brand.ringOuter)
                }
                SecondaryButton(title: "Add from contacts") { addingFromContacts = true }
                Text("Tap anyone to move them. Tap the outer count to see everyone.")
                    .textStyle(.caption, color: Brand.inkMuted).frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Brand.space5)
            .padding(.vertical, 8)
        }
        .background(Brand.page.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Ring.self) { ring in EveryoneView(focus: ring) }
        .navigationDestination(for: UUID.self) { id in
            if let p = model.person(id) { PersonView(person: p) }
        }
        .sheet(item: $sheetPerson) { p in RingSheet(person: p).presentationDetents([.medium]) }
        .addFromContacts(isPresented: $addingFromContacts)
    }

    private func diagram(inner: [Person], middle: [Person], outerCount: Int) -> some View {
        let c = size / 2
        let innerShown = Array(inner.prefix(6))
        let middleShown = Array(middle.prefix(10))
        return ZStack {
            Circle().fill(Brand.ringOuter).frame(width: size, height: size)
            Circle().fill(Brand.ringMiddle).frame(width: 230, height: 230)
            Circle().fill(Brand.ringInner).frame(width: 120, height: 120)

            ForEach(Array(innerShown.enumerated()), id: \.element.id) { i, p in
                face(p, size: 44)
                    .position(point(index: i, of: innerShown.count, radius: innerShown.count == 1 ? 0 : 28, center: c, offset: -.pi / 2))
            }
            ForEach(Array(middleShown.enumerated()), id: \.element.id) { i, p in
                face(p, size: 40)
                    .position(point(index: i, of: middleShown.count, radius: 88, center: c, offset: -.pi / 3))
            }
            if inner.count > innerShown.count || middle.count > middleShown.count {
                Text("+\(inner.count - innerShown.count + middle.count - middleShown.count)")
                    .font(TypeStyle.caption.strong).foregroundStyle(Brand.ink)
                    .frame(width: 40, height: 40).background(Brand.card, in: Circle())
                    .position(x: c + 70, y: c + 70)
            }
            NavigationLink(value: Ring.outer) {
                Text(outerCount == 1 ? "1 more person" : "\(outerCount) more people")
                    .font(TypeStyle.callout.strong).foregroundStyle(Brand.action)
                    .padding(.vertical, 10).padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
            }
            .position(x: c, y: 28)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .contain)
    }

    private func face(_ p: Person, size: CGFloat) -> some View {
        Button { sheetPerson = p } label: { Face(person: p, size: size, fill: Brand.card) }
            .buttonStyle(.plain)
            .accessibilityLabel("\(p.name), \(p.ring.label)")
    }

    private func point(index: Int, of count: Int, radius: CGFloat, center: CGFloat, offset: Double) -> CGPoint {
        guard count > 0 else { return CGPoint(x: center, y: center) }
        let angle = offset + Double(index) * 2 * .pi / Double(count)
        return CGPoint(x: center + radius * CGFloat(cos(angle)), y: center + radius * CGFloat(sin(angle)))
    }

    private func ringRow(_ ring: Ring, count: Int, fill: Color) -> some View {
        NavigationLink(value: ring) {
            HStack(spacing: 12) {
                Circle().fill(fill).frame(width: 20, height: 20).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ring.label).font(TypeStyle.body.strong).foregroundStyle(Brand.ink)
                    Text(ring.promise).textStyle(.caption, color: Brand.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(count)").font(TypeStyle.callout.strong).foregroundStyle(Brand.inkMuted)
            }
            .padding(.vertical, Brand.space3).padding(.horizontal, Brand.space4)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Everyone, by ring. Tap a person to see them.
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
