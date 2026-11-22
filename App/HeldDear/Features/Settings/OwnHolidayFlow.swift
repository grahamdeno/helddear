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

    var body: some View {
        let people = model.allPeople().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        FlowScreen(onClose: close) {
            Question(title: editing == nil ? "Add a holiday" : "Change \(editing!.name)",
                     subtitle: "It keeps this date every year. If it moves, change it here.", style: .title)
            VStack(alignment: .leading, spacing: Brand.space2) {
                Eyebrow(text: "What is it called?")
                TextField("Hanukkah, Diwali, Grandparents Day…", text: $name)
                    .font(Brand.display(28, relativeTo: .title2))
                    .padding(.vertical, Brand.space2)
                    .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
            }
            VStack(alignment: .leading, spacing: Brand.space2) {
                Eyebrow(text: "When this year")
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact).labelsHidden()
                    .tint(Brand.action)
            }
            VStack(alignment: .leading, spacing: Brand.space2) {
                HStack {
                    Eyebrow(text: "Who celebrates it with you?")
                    Spacer()
                    TextLink(title: chosen.count == people.count ? "No one" : "Everyone") {
                        chosen = chosen.count == people.count ? [] : Set(people.map(\.id))
                    }
                }
                FlowChips(people: people, chosen: $chosen)
            }
            if let problem { Text(problem).textStyle(.bodyStrong, color: Brand.error) }
            if editing != nil {
                TextLink(title: "Remove \(editing!.name)") { confirmRemove = true }.padding(.leading, -8)
            }
        } footer: {
            PrimaryButton(title: editing == nil ? "Add \(name.trimmingCharacters(in: .whitespaces).isEmpty ? "it" : name.trimmingCharacters(in: .whitespaces))" : "Save") { save(people) }
        }
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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let p = CustomHolidays.problem(name: trimmed, month: month, day: day, existing: CustomHolidays.all(), except: editing?.name) {
            problem = CustomHolidays.problemText(p)
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

/// People as chips that wrap, any number chosen.
private struct FlowChips: View {
    let people: [Person]
    @Binding var chosen: Set<UUID>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(people, id: \.id) { p in
                let on = chosen.contains(p.id)
                Button {
                    if on { chosen.remove(p.id) } else { chosen.insert(p.id) }
                } label: {
                    HStack(spacing: 6) {
                        if on { Image(systemName: "checkmark").font(.footnote.weight(.bold)) }
                        Text(DisplayName.plain(p.name)).font(.callout.weight(.semibold)).lineLimit(1)
                    }
                    .foregroundStyle(on ? Brand.page : Brand.ink)
                    .padding(.horizontal, 14).frame(minHeight: 44).frame(maxWidth: .infinity)
                    .background { if on { Capsule().fill(Brand.ink) } else { Capsule().strokeBorder(Brand.inkMuted, lineWidth: 1) } }
                    .contentShape(Capsule())
                }
                .buttonStyle(PressStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
