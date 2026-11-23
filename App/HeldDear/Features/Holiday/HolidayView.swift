import SwiftUI

/// A shared holiday's page (roadmap Epic 1, stories 1.2, 1.3 and 1.6): everyone on one page with how ready each
/// person is, from their own plan. Tap a person to plan them; their plan is saved to them.
struct HolidayView: View {
    @EnvironmentObject var model: AppModel
    let ref: HolidayRef
    private var type: OccasionType { ref.type }
    let year: Int

    private enum Screen: Equatable { case list, add }
    @State private var screen: Screen = .list
    @State private var started = false
    @State private var editingTradition: Tradition?
    @State private var traditionsRevision = 0

    private var members: [Moment] {
        let _ = model.revision
        return model.holidayMembers(ref: ref, year: year)
    }

    var body: some View {
        switch screen {
        case .list: listScreen.onAppear(perform: startPlans)
        case .add: addScreen
        }
    }

    /// Everyone on the holiday starts with suggested parts for their relationship, once (roadmap 1.6).
    private func startPlans() {
        guard !started else { return }
        started = true
        for m in members { model.startHolidayPlan(m) }
    }

    private var dueDate: Date? { members.first?.dueDate }
    private var days: Int { dueDate.map { OccasionDates.daysBetween(Date(), $0) } ?? 0 }

    private struct Row: Identifiable {
        let id: UUID
        let personID: UUID
        let name: String
        let ready: Int
        let total: Int
        let progress: [PartSteps.Progress]
    }

    private var rows: [Row] {
        members.compactMap { m in
            guard let p = m.person else { return nil }
            let parts = m.planParts
            let progress = parts.map {
                PartSteps.progress(step: $0.currentStep ?? "open", family: PartSteps.family(forKindRaw: $0.kindRaw))
            }
            return Row(id: m.id, personID: p.id, name: p.name, ready: progress.filter { $0 == .ready }.count, total: parts.count, progress: progress)
        }
    }

    private var listScreen: some View {
        let rows = self.rows
        let peopleReady = rows.filter { $0.total > 0 && $0.ready == $0.total }.count
        let things = rows.map(\.total).reduce(0, +)
        let thingsReady = rows.map(\.ready).reduce(0, +)
        let next = Holidays.nextUp(rows.map { (name: $0.name, ready: $0.ready, total: $0.total) })
        return FlowScreen {
            Eyebrow(text: eyebrow)
            Text(ref.label)
                .font(Brand.display(60, relativeTo: .largeTitle)).tracking(-1)
                .foregroundStyle(Brand.ink)
                .lineLimit(2).minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Brand.space2) {
                Text(Holidays.subline(daysLeft: days, people: rows.count))
                    .font(Brand.serif(20, relativeTo: .body)).foregroundStyle(Brand.inkSoft)
                Text(Holidays.summary(peopleReady: peopleReady, people: rows.count, thingsReady: thingsReady, things: things))
                    .textStyle(.callout, color: Brand.inkSoft)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            VStack(spacing: 0) {
                ForEach(rows) { row in personRow(row) }
                TextLink(title: "+ Add people to \(ref.label)") { screen = .add }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Brand.space2)
            }
            traditionsSection
        } footer: {
            if let next {
                PrimaryButton(title: "Plan \(rows[next].name) next") { open(rows[next]) }
            } else if !rows.isEmpty {
                PrimaryButton(title: "Everyone is ready") {}
                    .disabled(true).opacity(0.45)
            }
        }
    }

    // MARK: Traditions (Graham, Nov 22, 2026)

    /// Things given every year, set up once for the people chosen ("Ornament" for each kid at Christmas).
    private var traditionsSection: some View {
        let _ = traditionsRevision
        let list = Traditions.forHoliday(ref.raw)
        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Traditions").padding(.top, Brand.space5).padding(.bottom, Brand.space2)
            if list.isEmpty {
                Text("Something you give the same people every \(ref.label), set up once.")
                    .textStyle(.callout, color: Brand.inkMuted).padding(.bottom, Brand.space2)
            }
            ForEach(list) { t in
                Button { editingTradition = t } label: {
                    HStack(spacing: Brand.space3) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.name).textStyle(.bodyStrong, color: t.on ? Brand.ink : Brand.inkMuted)
                            Text(traditionLine(t)).textStyle(.caption, color: Brand.inkMuted).lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Brand.inkMuted)
                    }
                    .padding(.vertical, Brand.space3)
                    .frame(minHeight: 56)
                    .overlay(alignment: .top) { Rectangle().fill(Brand.line).frame(height: 1) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityHint("Change who gets it, or stop it")
            }
            TextLink(title: "+ Add a tradition") {
                editingTradition = Tradition(holiday: ref.raw, name: "")
            }
            .padding(.leading, -8)
        }
        .sheet(item: $editingTradition, onDismiss: { traditionsRevision += 1 }) { t in
            TraditionEditor(tradition: t, ref: ref, people: members.compactMap(\.person)).environmentObject(model)
        }
    }

    private func traditionLine(_ t: Tradition) -> String {
        let names = t.recipientIDs.compactMap { model.person($0).map { DisplayName.plain($0.name) } }
        let who = names.isEmpty ? "No one yet" : "For " + ListFormatter.localizedString(byJoining: names)
        return t.on ? "\(who), every year" : "\(who) · Off"
    }

    private var eyebrow: String {
        guard let dueDate else { return ref.label.uppercased() }
        var bits = [dueDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())]
        if days == 0 { bits.append("TODAY") } else if days == 1 { bits.append("1 DAY") } else if days > 1 { bits.append("\(days) DAYS") }
        return bits.joined(separator: " · ").uppercased()
    }

    /// A person's row opens their own page, with this holiday shown first.
    private func open(_ row: Row) { model.push(.person(row.personID, focus: row.id)) }

    private func readyText(_ row: Row) -> String {
        if row.total == 0 { return "Nothing planned yet" }
        return row.ready == row.total ? "Ready" : "\(row.ready) of \(row.total) ready"
    }

    private func personRow(_ row: Row) -> some View {
        Button { open(row) } label: {
            HStack(spacing: Brand.space3) {
                // Each person's face, framed on it like Home's circle; their initial when there's no photo.
                PersonPortrait(person: model.person(row.personID), size: 44)
                VStack(alignment: .leading, spacing: Brand.space2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.name).font(Brand.serif(22, relativeTo: .title3)).foregroundStyle(Brand.ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: Brand.space2)
                        Text(readyText(row)).textStyle(.caption, color: Brand.inkMuted)
                    }
                    HStack(spacing: 3) {
                        ForEach(Array(row.progress.enumerated()), id: \.offset) { _, p in
                            Rectangle().fill(segmentColor(p)).frame(height: 6)
                        }
                    }
                    .accessibilityHidden(true)
                }
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Brand.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Brand.space3)
            .frame(minHeight: 72)
            .overlay(alignment: .top) { Rectangle().fill(Brand.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name), \(readyText(row))")
        .accessibilityHint("Opens \(row.name)'s plan for \(ref.label)")
        .accessibilityAddTraits(.isButton)
    }

    private func segmentColor(_ p: PartSteps.Progress) -> Color {
        switch p {
        case .ready: Brand.ink
        case .started: Brand.inkMuted.opacity(0.5)
        case .notStarted: Brand.line
        }
    }

    // MARK: Add people

    private var candidates: [Person] {
        let inHoliday = Set(members.compactMap { $0.person?.id })
        return model.allPeople().filter { !inHoliday.contains($0.id) }
    }

    private var addScreen: some View {
        FlowScreen {
            TextLink(title: "‹ \(ref.label)") { screen = .list }
            Question(title: "Who else is part of \(ref.label)?",
                     subtitle: "Each person starts with what families usually plan for them.")
            VStack(spacing: 0) {
                if candidates.isEmpty {
                    Text("Everyone in Held Dear is already here.").textStyle(.body, color: Brand.inkMuted)
                }
                ForEach(candidates, id: \.id) { p in
                    Button {
                        model.addToHoliday(p, ref: ref, year: year)
                    } label: {
                        HStack(spacing: Brand.space3) {
                            Text(p.name).textStyle(.bodyStrong).frame(maxWidth: .infinity, alignment: .leading)
                            Text("Add").font(.callout.weight(.semibold)).foregroundStyle(Brand.action)
                        }
                        .padding(.vertical, Brand.space4)
                        .frame(minHeight: 56)
                        .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Add \(p.name) to \(ref.label)")
                }
            }
        } footer: {
            PrimaryButton(title: "Done") { screen = .list }
        }
    }
}

/// Home's featured view for a shared holiday: the holiday's name large, who it's for, one readiness bar, one action.
struct HolidayFeaturedView: View {
    @EnvironmentObject var model: AppModel
    let ref: HolidayRef
    private var type: OccasionType { ref.type }
    let members: [Moment]
    let now: Date

    var body: some View {
        let due = members.first?.dueDate ?? now
        let days = OccasionDates.daysBetween(now, due)
        let rows = members.map { m -> (ready: Int, total: Int) in
            let parts = m.planParts
            return (parts.filter(\.isReady).count, parts.count)
        }
        let peopleReady = rows.filter { $0.total > 0 && $0.ready == $0.total }.count
        let things = rows.map(\.total).reduce(0, +)
        let thingsReady = rows.map(\.ready).reduce(0, +)
        let year = Calendar.current.component(.year, from: due)

        let progress = members.flatMap { m in
            m.planParts.map { PartSteps.progress(step: $0.currentStep ?? "open", family: PartSteps.family(forKindRaw: $0.kindRaw)) }
        }
        // The same fixed places as a person's day, so sliding between them doesn't move anything.
        FeaturedSlots(
            eyebrow: due.formatted(.dateTime.weekday(.wide).month(.wide).day()),
            title: ref.label, open: { model.push(.holiday(ref.raw, year)) }, openHint: "Opens \(ref.label)",
            subline: Holidays.subline(daysLeft: days, people: members.count),
            progress: progress,
            status: Holidays.summary(peopleReady: peopleReady, people: members.count, thingsReady: thingsReady, things: things)
        ) {
            PrimaryButton(title: "Plan \(ref.label)") { model.push(.holiday(ref.raw, year)) }
        } link: {
            EmptyView()
        }
    }
}

/// Sets up or changes a holiday tradition (Graham, Nov 22, 2026): its name, who it's from, who gets it.
struct TraditionEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var tradition: Tradition
    let ref: HolidayRef
    /// The people in this holiday, to choose from.
    let people: [Person]

    private var isNew: Bool { !Traditions.all().contains { $0.id == tradition.id } }
    /// Who can give it: you, and the household (partner and the like).
    private var givers: [Person] {
        model.allPeople().filter { Relationship.isHouseholdGiver(relationship: $0.relationship, isInner: $0.ring == .inner) }
    }

    var body: some View {
        FlowScreen(onClose: { dismiss() }) {
            Question(title: isNew ? "A \(ref.label) tradition" : tradition.name,
                     subtitle: "It goes into each chosen person's plan every year, starting this \(ref.label), each with its own steps.",
                     style: .title)
            LineField(label: "What is it?", text: $tradition.name, placeholder: "Ornament", showsDictation: false)
            Eyebrow(text: "Who gets it").padding(.top, Brand.space3)
            VStack(spacing: 0) {
                if people.isEmpty {
                    Text("Add people to \(ref.label) first.").textStyle(.callout, color: Brand.inkMuted)
                }
                ForEach(people, id: \.id) { p in
                    checkRow(DisplayName.plain(p.name), on: tradition.recipientIDs.contains(p.id)) {
                        toggle(p.id, in: \.recipientIDs)
                    }
                }
            }
            Eyebrow(text: "From").padding(.top, Brand.space3)
            VStack(spacing: 0) {
                checkRow("You", on: tradition.giverIDs.isEmpty) { tradition.giverIDs = [] }
                ForEach(givers, id: \.id) { p in
                    checkRow(DisplayName.plain(p.name), on: tradition.giverIDs.contains(p.id)) {
                        toggle(p.id, in: \.giverIDs)
                    }
                }
            }
            if !isNew {
                Toggle(isOn: $tradition.on) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Every year").textStyle(.body)
                        Text("Off stops adding it. Items already in a plan stay.").textStyle(.caption, color: Brand.inkMuted)
                    }
                }
                .tint(Brand.action)
                .padding(.top, Brand.space3)
                TextLink(title: "Remove this tradition") {
                    Traditions.remove(tradition.id)
                    dismiss()
                }
                .padding(.leading, -8)
            }
        } footer: {
            PrimaryButton(title: isNew ? "Add the tradition" : "Save") {
                tradition.name = tradition.name.trimmingCharacters(in: .whitespacesAndNewlines)
                Traditions.upsert(tradition)
                model.applyTraditions()
                dismiss()
            }
            .disabled(tradition.name.trimmingCharacters(in: .whitespaces).isEmpty || tradition.recipientIDs.isEmpty)
        }
    }

    private func toggle(_ id: UUID, in path: WritableKeyPath<Tradition, [UUID]>) {
        if let i = tradition[keyPath: path].firstIndex(of: id) { tradition[keyPath: path].remove(at: i) }
        else { tradition[keyPath: path].append(id) }
    }

    private func checkRow(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).textStyle(.body)
                Spacer()
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                    .foregroundStyle(on ? Brand.action : Brand.inkMuted)
            }
            .frame(minHeight: 52)
            .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
