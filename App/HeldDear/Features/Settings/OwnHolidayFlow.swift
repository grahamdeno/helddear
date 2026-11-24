import SwiftUI

/// Add or change a holiday of the user's own (story 2.10, approved Nov 21, 2026): a name, the date this year (the
/// same date every year after), and who celebrates it. It then works like Christmas: on Home, on each person's page,
/// a plan and gift ideas, and alerts.
struct OwnHolidayFlow: View {
    @EnvironmentObject var model: AppModel
    /// The holiday being changed, or nil to add one.
    let editing: CustomHoliday?
    var close: () -> Void

    @State private var name = ""
    @State private var date = Date()
    @State private var chosen: Set<UUID> = []
    @State private var problem: String?
    @State private var confirmRemove = false
    /// One decision per screen (Graham, Nov 22, 2026): what it is, when (only if Held Dear can't tell), who.
    private enum Step { case name, date, who, pick }
    @State private var step: Step = .name
    @State private var known: KnownHoliday?
    @State private var search = ""

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        let people = model.allPeople().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        Group {
            switch step {
            case .name: nameStep
            case .date: dateStep
            case .who: whoStep(people)
            case .pick: pickStep(people)
            }
        }
        .animation(Motion.animation(.easeOut(duration: 0.2)), value: step)
        .onAppear(perform: load)
        .confirmationDialog("Remove \(editing?.name ?? "")?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let e = editing { model.removeCustomHoliday(e.name) }
                close()
            }
        } message: {
            Text("It comes off every timeline. Past years stay in each person's record.")
        }
    }

    // MARK: 1. What holiday?

    private var nameStep: some View {
        FlowScreen(onClose: close) {
            Question(title: editing == nil ? "What holiday?" : "Change \(editing!.name)",
                     subtitle: "Pick one Held Dear knows, and it fills in the date, or type your own.", style: .title)
            TextField("Type a holiday", text: $name)
                .font(Brand.display(28, relativeTo: .title2))
                .submitLabel(.next)
                .onSubmit { nameDone() }
                .padding(.vertical, Brand.space2)
                .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
            let matches = KnownHolidays.matches(name)
            VStack(spacing: 0) {
                ForEach(matches.prefix(trimmed.isEmpty ? 8 : 5), id: \.name) { h in
                    let next = h.nextDate(onOrAfter: Date())
                    OptionRow(title: h.name,
                              caption: next.map { $0.formatted(.dateTime.weekday(.wide).month(.wide).day().year()) } ?? "You pick the day") {
                        name = h.name
                        nameDone()
                    }
                }
                if !trimmed.isEmpty && KnownHolidays.named(trimmed) == nil {
                    OptionRow(title: "Use \u{201C}\(trimmed)\u{201D}", caption: "You pick the day") { nameDone() }
                }
            }
            if editing != nil {
                TextLink(title: "Remove \(editing!.name)") { confirmRemove = true }.padding(.leading, -8)
            }
        }
    }

    private func nameDone() {
        guard !trimmed.isEmpty else { return }
        known = KnownHolidays.named(trimmed)
        if let next = known?.nextDate(onOrAfter: Date()) {
            date = next
            step = .who
        } else {
            if editing == nil { date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date() }
            step = .date
        }
    }

    // MARK: 2. When is it this year? (only when Held Dear can't tell)

    private var dateStep: some View {
        FlowScreen(onClose: { step = .name }) {
            Question(title: "When is \(trimmed) this year?",
                     subtitle: "It keeps this date every year. Six weeks before, Held Dear asks if it moved.", style: .title)
            DatePicker("Date", selection: $date, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                .datePickerStyle(.graphical).labelsHidden()
                .tint(Brand.action)
        } footer: {
            PrimaryButton(title: "Next") { step = .who }
        }
    }

    // MARK: 3. Who celebrates it with you?

    private func groups(_ people: [Person]) -> [(title: String, caption: String, ids: Set<UUID>)] {
        let household = people.filter { [.partner, .child].contains(Relationship.group($0.relationship)) }
        let family = people.filter { [.partner, .child, .parent, .sibling, .extended].contains(Relationship.group($0.relationship)) }
        var out: [(String, String, Set<UUID>)] = []
        if !household.isEmpty { out.append(("Your household", names(household), Set(household.map(\.id)))) }
        if family.count > household.count { out.append(("Family", names(family), Set(family.map(\.id)))) }
        out.append(("Everyone", "\(people.count) people", Set(people.map(\.id))))
        return out
    }

    private func names(_ people: [Person]) -> String {
        let first = people.prefix(3).map { DisplayName.plain($0.name) }
        return people.count > 3 ? first.joined(separator: ", ") + " and \(people.count - 3) more" : ListFormatter.localizedString(byJoining: first)
    }

    private func whoStep(_ people: [Person]) -> some View {
        FlowScreen(onClose: { step = known?.nextDate(onOrAfter: Date()) == nil ? .date : .name }) {
            Question(title: "Who celebrates \(trimmed) with you?",
                     subtitle: date.formatted(.dateTime.weekday(.wide).month(.wide).day()), style: .title)
            VStack(spacing: 0) {
                ForEach(groups(people), id: \.title) { g in
                    OptionRow(title: g.title, caption: g.caption) {
                        chosen = g.ids
                        save(people)
                    }
                }
                OptionRow(title: "Pick people", caption: chosen.isEmpty ? "Choose one by one" : "\(chosen.count) chosen") { step = .pick }
            }
            if let problem { Text(problem).textStyle(.bodyStrong, color: Brand.error) }
        }
    }

    private func pickStep(_ people: [Person]) -> some View {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let shown = q.isEmpty ? people : people.filter { $0.name.lowercased().contains(q) }
        return FlowScreen(onClose: { step = .who }) {
            Question(title: "Who celebrates \(trimmed) with you?", subtitle: "\(chosen.count) chosen", style: .title)
            TextField("Search", text: $search)
                .textStyle(.body)
                .padding(.horizontal, Brand.space4).frame(minHeight: 48)
                .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
            VStack(spacing: 0) {
                ForEach(shown, id: \.id) { p in
                    let on = chosen.contains(p.id)
                    Button {
                        if on { chosen.remove(p.id) } else { chosen.insert(p.id) }
                    } label: {
                        HStack(spacing: Brand.space3) {
                            Face(person: p, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(DisplayName.plain(p.name)).textStyle(.body)
                                if let r = p.relationship { Text(r).textStyle(.caption, color: Brand.inkMuted) }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.title3).foregroundStyle(on ? Brand.action : Brand.inkMuted)
                        }
                        .padding(.vertical, Brand.space2)
                        .frame(minHeight: 56)
                        .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                }
            }
        } footer: {
            PrimaryButton(title: editing == nil ? "Add \(trimmed)" : "Save") { save(people) }
        }
    }

    private func load() {
        guard let e = editing else { return }
        name = e.name
        let year = Calendar.current.component(.year, from: Date())
        date = OccasionDates.date(month: e.month, day: e.day, year: year)
        chosen = Set(model.customHolidayPeople(e.name).map(\.id))
    }

    private func save(_ people: [Person]) {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        let month = c.month ?? 1, day = c.day ?? 1
        if let p = CustomHolidays.problem(name: trimmed, month: month, day: day, existing: CustomHolidays.all(), except: editing?.name) {
            problem = CustomHolidays.problemText(p)
            step = .who
            return
        }
        let holiday = CustomHoliday(name: trimmed, month: month, day: day)
        let picked = people.filter { chosen.contains($0.id) }
        if let e = editing {
            model.updateCustomHoliday(old: e.name, to: holiday)
            let had = Set(model.customHolidayPeople(holiday.name).map(\.id))
            let year = Calendar.current.component(.year, from: Date())
            for p in picked where !had.contains(p.id) { model.addToHoliday(p, ref: holiday.ref, year: year) }
            for p in people where had.contains(p.id) && !chosen.contains(p.id) {
                if let o = p.occasions.first(where: { $0.type == .custom && CustomHolidays.sameName($0.partnerName ?? "", holiday.name) }) {
                    model.removeOccasion(o)
                }
            }
        } else {
            model.addCustomHoliday(holiday, people: picked)
        }
        close()
    }
}
