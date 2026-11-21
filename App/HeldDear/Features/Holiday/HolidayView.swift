import SwiftUI

/// A shared holiday's page (roadmap Epic 1, stories 1.2, 1.3 and 1.6): everyone on one page with how ready each
/// person is, from their own plan. Tap a person to plan them; their plan is saved to them.
struct HolidayView: View {
    @EnvironmentObject var model: AppModel
    let type: OccasionType
    let year: Int

    private enum Screen: Equatable { case list, add }
    @State private var screen: Screen = .list
    @State private var started = false

    private var members: [Moment] {
        let _ = model.revision
        return model.holidayMembers(type: type, year: year)
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
            Text(type.label)
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
                TextLink(title: "+ Add people to \(type.label)") { screen = .add }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Brand.space2)
            }
        } footer: {
            if let next {
                PrimaryButton(title: "Plan \(rows[next].name) next") { open(rows[next]) }
            } else if !rows.isEmpty {
                PrimaryButton(title: "Everyone is ready") {}
                    .disabled(true).opacity(0.45)
            }
        }
    }

    private var eyebrow: String {
        guard let dueDate else { return type.label.uppercased() }
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
                Text(String(row.name.prefix(1)))
                    .font(Brand.display(20, relativeTo: .title3)).foregroundStyle(Brand.ink)
                    .frame(width: 44, height: 44)
                    .background(Brand.faceFill(for: row.name), in: Circle())
                    .accessibilityHidden(true)
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
        .accessibilityHint("Opens \(row.name)'s plan for \(type.label)")
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
            TextLink(title: "‹ \(type.label)") { screen = .list }
            Question(title: "Who else is part of \(type.label)?",
                     subtitle: "Each person starts with what families usually plan for them.")
            VStack(spacing: 0) {
                if candidates.isEmpty {
                    Text("Everyone in Held Dear is already here.").textStyle(.body, color: Brand.inkMuted)
                }
                ForEach(candidates, id: \.id) { p in
                    Button {
                        model.addToHoliday(p, type: type, year: year)
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
                    .accessibilityLabel("Add \(p.name) to \(type.label)")
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
    let type: OccasionType
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
            title: type.label, open: { model.push(.holiday(type.rawValue, year)) }, openHint: "Opens \(type.label)",
            subline: Holidays.subline(daysLeft: days, people: members.count),
            progress: progress,
            status: Holidays.summary(peopleReady: peopleReady, people: members.count, thingsReady: thingsReady, things: things)
        ) {
            PrimaryButton(title: "Plan \(type.label)") { model.push(.holiday(type.rawValue, year)) }
        } link: {
            EmptyView()
        }
    }
}
