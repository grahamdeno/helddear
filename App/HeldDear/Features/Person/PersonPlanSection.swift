import SwiftUI

/// One day's plan on a person's page (approved Nov 20, 2026): a count line, then the items grouped by what they are
/// (Gifts, The day, Little touches), each group on a stone card. Every item has a circle: empty to decide, half on
/// the way, filled when ready; the step word shows only once it's started. Then one button for the next decision.
/// Every rule is in Domain; this view only draws it.
struct PersonPlanSection: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    let add: () -> Void

    private struct Item: Identifiable {
        let id: UUID
        let name: String
        let note: String?
        let step: String
        let owner: String
        let progress: PartSteps.Progress
        let group: PlanGroup
    }

    private var items: [Item] {
        let household = model.household(for: moment.person)
        return moment.planParts.map { act in
            let ownerNames = household.filter { PartOwners.existing(act.ownerIDs, among: household.map(\.id)).contains($0.id) }.map(\.name)
            let kidsName = act.kind == .kidsMade && act.label == nil ? PartOwners.kidsGiftName(names: ownerNames) : nil
            let name = kidsName ?? PartSteps.displayName(kindRaw: act.kindRaw, label: act.label, title: act.title)
            let step = act.currentStep ?? "open"
            let family = PartSteps.family(forKindRaw: act.kindRaw)
            let note = act.note?.trimmingCharacters(in: .whitespacesAndNewlines)
            return Item(id: act.id, name: name, note: (note?.isEmpty ?? true) ? nil : note, step: step,
                        owner: PartOwners.text(names: ownerNames),
                        progress: PartSteps.progress(step: step, family: family), group: PlanGroup.group(forKindRaw: act.kindRaw))
        }
    }

    var body: some View {
        let _ = model.revision
        let items = self.items
        let nudge = moment.planNudge
        VStack(alignment: .leading, spacing: Brand.space3) {
            if items.isEmpty {
                Text("Nothing planned yet.").font(Brand.serif(19, relativeTo: .body, italic: true)).foregroundStyle(Brand.inkSoft)
            } else {
                countLine(items)
                ForEach(PlanGroup.allCases, id: \.self) { g in
                    let rows = items.filter { $0.group == g }.sorted { rank($0.progress) < rank($1.progress) }
                    if !rows.isEmpty { groupCard(g, rows) }
                }
            }
            if nudge.isEnabled, let t = nudge.target, moment.planParts.indices.contains(t) {
                let target = moment.planParts[t].id
                PrimaryButton(title: nudge.buttonTitle) { model.push(.item(target)) }
                    .padding(.top, Brand.space2)
            }
            TextLink(title: "+ Add to \(moment.label)", action: add)
                .padding(.leading, -8)
        }
    }

    private func rank(_ p: PartSteps.Progress) -> Int {
        switch p {
        case .notStarted: 0
        case .started: 1
        case .ready: 2
        }
    }

    private func countLine(_ items: [Item]) -> some View {
        let todo = items.filter { $0.progress == .notStarted }.count
        let way = items.filter { $0.progress == .started }.count
        let ready = items.filter { $0.progress == .ready }.count
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: Brand.space4) { counts(todo, way, ready) }
            VStack(alignment: .leading, spacing: Brand.space1) { counts(todo, way, ready) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PlanGroup.countLine(toDecide: todo, onTheWay: way, ready: ready))
    }

    @ViewBuilder private func counts(_ todo: Int, _ way: Int, _ ready: Int) -> some View {
        countItem(.notStarted, "\(todo) to decide")
        countItem(.started, "\(way) on the way")
        countItem(.ready, "\(ready) ready")
    }

    private func countItem(_ p: PartSteps.Progress, _ text: String) -> some View {
        HStack(spacing: 6) {
            StepCircle(progress: p, size: 13)
            Text(text).textStyle(.callout, color: Brand.inkSoft)
        }
    }

    private func groupCard(_ g: PlanGroup, _ rows: [Item]) -> some View {
        let ready = rows.filter { $0.progress == .ready }.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(g.title).font(Brand.serif(20, relativeTo: .title3)).foregroundStyle(Brand.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Brand.space2)
                Text(PlanGroup.summary(ready: ready, total: rows.count)).textStyle(.caption, color: Brand.inkMuted)
            }
            .padding(.bottom, Brand.space1)
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, item in
                row(item, first: i == 0)
            }
        }
        .padding(.horizontal, Brand.space4)
        .padding(.top, Brand.space3)
        .padding(.bottom, Brand.space1)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ item: Item, first: Bool) -> some View {
        Button { model.push(.item(item.id)) } label: {
            HStack(spacing: Brand.space3) {
                StepCircle(progress: item.progress, size: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name).textStyle(.bodyStrong, color: item.progress == .ready ? Brand.inkMuted : Brand.ink)
                        .multilineTextAlignment(.leading)
                    if let note = item.note {
                        Text(note).textStyle(.caption, color: Brand.inkMuted).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if item.progress != .notStarted {
                    Text(PartSteps.word(for: item.step)).textStyle(.caption, color: Brand.inkSoft).lineLimit(1)
                }
            }
            .frame(minHeight: 48)
            .overlay(alignment: .top) { if !first { Rectangle().fill(Brand.line).frame(height: 1) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(PartOwners.rowLabel(name: item.name, owner: item.owner, step: item.step))
        .accessibilityHint("Opens this item")
    }
}

/// Where an item stands, as a circle: empty to decide, half on the way, filled with a check when ready. The words
/// always sit beside it, so the circle is never the only signal.
struct StepCircle: View {
    let progress: PartSteps.Progress
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            switch progress {
            case .notStarted:
                Circle().strokeBorder(Brand.inkMuted, lineWidth: 1.5)
            case .started:
                Circle().strokeBorder(Brand.ink, lineWidth: 1.5)
                HalfDisc().fill(Brand.ink).padding(1.5)
            case .ready:
                Circle().fill(Brand.ink)
                Image(systemName: "checkmark").font(.system(size: size * 0.5, weight: .bold)).foregroundStyle(Brand.page)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The left half of a circle.
private struct HalfDisc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addArc(center: c, radius: min(rect.width, rect.height) / 2, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        p.closeSubpath()
        return p
    }
}

/// The day cards on a person's page: one per coming day, left to right in date order, each with a big countdown and
/// its own readiness bar. The selected card is filled; the plan below is its plan.
struct PersonDayCards: View {
    let moments: [Moment]
    @Binding var selectedID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Brand.space3) {
                ForEach(moments, id: \.id) { m in card(m) }
            }
            .padding(.horizontal, Brand.space5)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .padding(.horizontal, -Brand.space5)
    }

    private func countdown(_ m: Moment) -> (big: String, unit: String) {
        let days = OccasionDates.daysBetween(Date(), m.dueDate)
        if days <= 0 { return ("Today", "") }
        if days < 60 { return ("\(days)", days == 1 ? "day" : "days") }
        let months = Int((Double(days) / 30.4).rounded())
        return ("\(months)", "months")
    }

    private func card(_ m: Moment) -> some View {
        let on = m.id == selectedID
        let parts = m.planParts
        let progress = parts.map { PartSteps.progress(step: $0.currentStep ?? "open", family: PartSteps.family(forKindRaw: $0.kindRaw)) }
        let ready = progress.filter { $0 == .ready }.count
        let fg = on ? Brand.page : Brand.ink
        let c = countdown(m)
        var date = m.dueDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        if let count = m.countLine { date += " · " + count.prefix(1).lowercased() + count.dropFirst() }
        return Button { selectedID = m.id } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(m.label.uppercased()).font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(fg.opacity(0.8))
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(c.big).font(Brand.display(52, relativeTo: .largeTitle)).foregroundStyle(fg)
                    Text(c.unit).textStyle(.callout, color: fg.opacity(0.85))
                }
                Text(date).textStyle(.caption, color: fg.opacity(0.85)).lineLimit(1)
                HStack(spacing: 3) {
                    if progress.isEmpty {
                        Rectangle().fill(on ? Brand.inkMuted : Brand.line).frame(height: 5)
                    } else {
                        ForEach(Array(progress.enumerated()), id: \.offset) { _, p in
                            Rectangle().fill(segment(p, on: on)).frame(height: 5)
                        }
                    }
                }
                .padding(.top, Brand.space3)
                Text(parts.isEmpty ? "Nothing planned yet" : "\(ready) of \(parts.count) ready")
                    .textStyle(.caption, color: fg.opacity(0.9)).lineLimit(1)
                    .padding(.top, Brand.space1)
            }
            .padding(Brand.space4)
            .frame(width: 236, alignment: .leading)
            .background(on ? Brand.ink : Brand.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? Brand.ink : Brand.line, lineWidth: 1) }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(m.label), \(c.big) \(c.unit), \(parts.isEmpty ? "nothing planned" : "\(ready) of \(parts.count) ready")")
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func segment(_ p: PartSteps.Progress, on: Bool) -> Color {
        switch p {
        case .ready: on ? Brand.page : Brand.ink
        case .started: Brand.inkMuted
        case .notStarted: on ? Brand.inkSoft.opacity(0.6) : Brand.line
        }
    }
}
