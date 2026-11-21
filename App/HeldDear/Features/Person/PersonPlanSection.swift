import SwiftUI

/// One occasion's plan on a person's page (version B, approved Nov 20, 2026): how ready it is, then its items in
/// three groups (To decide, On the way, Ready). Tap an item to open it. The plan is the person's page, not a second
/// view of them. Every rule is in Domain; this view only draws it.
struct PersonPlanSection: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    /// The first occasion on the page gets the page's one main button; the others get a text link.
    let primary: Bool
    let add: () -> Void

    private struct Item: Identifiable {
        let id: UUID
        let name: String
        let step: String
        let owner: String
        let progress: PartSteps.Progress
    }

    private var items: [Item] {
        let household = model.household(for: moment.person)
        return moment.planParts.map { act in
            let ownerNames = household.filter { PartOwners.existing(act.ownerIDs, among: household.map(\.id)).contains($0.id) }.map(\.name)
            let kidsName = act.kind == .kidsMade && act.label == nil ? PartOwners.kidsGiftName(names: ownerNames) : nil
            let name = kidsName ?? PartSteps.displayName(kindRaw: act.kindRaw, label: act.label, title: act.title)
            let step = act.currentStep ?? "open"
            let family = PartSteps.family(forKindRaw: act.kindRaw)
            return Item(id: act.id, name: name, step: step, owner: PartOwners.text(names: ownerNames),
                        progress: PartSteps.progress(step: step, family: family))
        }
    }

    private var days: Int { OccasionDates.daysBetween(Date(), moment.dueDate) }

    private var head: String {
        var bits = [moment.label, moment.dueDate.formatted(.dateTime.month(.abbreviated).day())]
        if days == 0 { bits.append("Today") } else if days == 1 { bits.append("1 day") } else if days > 1 { bits.append("\(days) days") }
        return bits.joined(separator: " · ").uppercased()
    }

    private var nudge: PlanNudge.Result { moment.planNudge }

    var body: some View {
        let _ = model.revision
        let items = self.items
        let ready = items.filter { $0.progress == .ready }.count
        let nudge = self.nudge
        VStack(alignment: .leading, spacing: Brand.space3) {
            Eyebrow(text: head)
            if items.isEmpty {
                Text("Nothing planned yet.").font(Brand.serif(19, relativeTo: .body, italic: true)).foregroundStyle(Brand.inkSoft)
            } else {
                VStack(alignment: .leading, spacing: Brand.space2) {
                    HStack(spacing: 4) {
                        ForEach(items) { item in
                            Rectangle().fill(color(item.progress)).frame(height: 6)
                        }
                    }
                    .accessibilityHidden(true)
                    Text(PlanReadiness.summary(ready: ready, total: items.count, subject: moment.subject))
                        .textStyle(.callout, color: Brand.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                group("To decide", items.filter { $0.progress == .notStarted })
                group("On the way", items.filter { $0.progress == .started })
                group("Ready", items.filter { $0.progress == .ready })
            }
            if nudge.isEnabled, let t = nudge.target, moment.planParts.indices.contains(t) {
                let target = moment.planParts[t].id
                if primary {
                    PrimaryButton(title: nudge.buttonTitle) { model.push(.item(target)) }
                } else {
                    TextLink(title: nudge.buttonTitle) { model.push(.item(target)) }
                }
            }
            TextLink(title: "+ Add to \(moment.label)", action: add)
                .padding(.leading, -8)
        }
    }

    @ViewBuilder private func group(_ title: String, _ items: [Item]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Brand.space2) {
                Text(title).textStyle(.caption, color: Brand.inkMuted).accessibilityAddTraits(.isHeader)
                FlowLayout(spacing: 8) {
                    ForEach(items) { item in chip(item) }
                }
            }
        }
    }

    private func chip(_ item: Item) -> some View {
        Button { model.push(.item(item.id)) } label: {
            HStack(spacing: 6) {
                if item.progress == .ready { Image(systemName: "checkmark").font(.footnote.weight(.bold)) }
                Text(item.name).font(.callout.weight(.semibold)).lineLimit(1)
                if item.progress == .started {
                    Text(PartSteps.word(for: item.step)).font(.caption).foregroundStyle(Brand.inkSoft).lineLimit(1)
                }
            }
            .foregroundStyle(Brand.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background {
                if item.progress == .ready {
                    Capsule().fill(Brand.card)
                } else {
                    Capsule().strokeBorder(item.progress == .started ? Brand.ink : Brand.inkMuted, lineWidth: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(PartOwners.rowLabel(name: item.name, owner: item.owner, step: item.step))
        .accessibilityHint("Opens this item")
    }

    private func color(_ p: PartSteps.Progress) -> Color {
        switch p {
        case .ready: Brand.ink
        case .started: Brand.inkMuted.opacity(0.5)
        case .notStarted: Brand.line
        }
    }
}
