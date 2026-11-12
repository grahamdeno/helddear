import SwiftUI
import UIKit

/// Home: upcoming Moments in date order, anything needing action at the top. A browse screen.
struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                content
                    .padding(.horizontal, Brand.space5)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .background(Brand.page.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                SecondaryButton(title: "Add a birthday") { model.route = .addBirthday }
                    .padding(.horizontal, Brand.space5)
                    .padding(.bottom, 8)
                    .background(Brand.page.opacity(0.95).ignoresSafeArea())
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.route = .rings } label: {
                        Image(systemName: "person.2.fill").font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .accessibilityLabel("Your people")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let p = model.person(id) { PersonView(person: p) }
            }
        }
    }

    @ViewBuilder private var content: some View {
        let _ = model.revision
        let moments = MomentEngine.visibleMoments(model.context)
        let action = moments.filter { MomentEngine.needsAction($0) }
        let rest = moments.filter { !MomentEngine.needsAction($0) }
        let isFirstVisit = !model.firstVisitCardDismissed

        VStack(alignment: .leading, spacing: 24) {
            Text("Coming up").textStyle(.title).accessibilityAddTraits(.isHeader)

            if moments.isEmpty {
                emptyState
            } else {
                if !action.isEmpty {
                    VStack(alignment: .leading, spacing: Brand.space2) {
                        Eyebrow(text: "Ready for you")
                        ForEach(action, id: \.id) { row($0, actionLine: true) }
                    }
                }
                if let season = upcomingSeason {
                    seasonCard(season)
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    if !action.isEmpty { Eyebrow(text: "Later") }
                    ForEach(isFirstVisit ? Array(rest.prefix(3)) : rest, id: \.id) { row($0, actionLine: false) }
                }
                if isFirstVisit { firstVisitCard }
            }

            accessLinks
        }
    }

    private var upcomingSeason: Season? {
        let now = Date()
        return model.seasons(now: now).first { s in
            let days = OccasionDates.daysBetween(now, s.monthStart)
            return days >= 0 && days <= 28
        }
    }

    private func row(_ m: Moment, actionLine: Bool) -> some View {
        let person = m.person
        let caption: String = actionLine ? actionText(m) : detail(m)
        return OptionRow(title: person?.name ?? "", caption: caption, action: { model.route = .moment(m.id, .auto) },
                         leading: { if let person { Face(person: person) } },
                         trailing: { Tag(text: OccasionDates.countdown(to: m.dueDate, from: Date())) })
            .contextMenu {
                if let person {
                    Button { path.append(person.id) } label: { Label("See \(person.name)", systemImage: "person.crop.circle") }
                    Button { model.route = .addWish(person.id) } label: { Label("Save a wish", systemImage: "gift") }
                }
            }
    }

    private func detail(_ m: Moment) -> String {
        let type = m.occasion?.type.label ?? "Birthday"
        if let t = m.turning { return "\(type) · turning \(t)" }
        return "\(type) · \(OccasionDates.longDate(m.dueDate))"
    }

    /// The same words the notification would have used, for people who turned alerts off.
    private func actionText(_ m: Moment) -> String {
        let name = m.person?.name ?? ""
        switch m.status {
        case .missed: return "\(name)'s birthday was yesterday. A late note still counts."
        case .planning:
            if OccasionDates.daysBetween(Date(), m.dueDate) == 0 { return "It's today. A message is ready." }
            return m.plan?.kind == .card ? "Mail-by day for the card" : "Order-by day for the gift"
        case .done: return "It's today. A message is ready."
        default:
            if OccasionDates.daysBetween(Date(), m.dueDate) == 0 { return "It's today. A message is ready." }
            let wishes = m.person?.openWishes.count ?? 0
            return wishes > 0 ? "What will you do? You saved \(wishes) idea\(wishes == 1 ? "" : "s")." : "What will you do?"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Brand.space4) {
            Text("Add your first person").textStyle(.headline)
            Text("Say or type a name and a birthday. Held Dear does the remembering.").textStyle(.body, color: Brand.ink.opacity(0.85))
            PrimaryButton(title: "Add a birthday") { model.route = .addBirthday }
        }
        .padding(20)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
    }

    private var firstVisitCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text("Has anyone here mentioned wanting something?").textStyle(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { model.firstVisitCardDismissed = true } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Brand.inkMuted)
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
        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
    }

    private func seasonCard(_ s: Season) -> some View {
        let month = s.monthStart.formatted(.dateTime.month(.wide))
        return OptionRow(title: "\(month) is a big month",
                         caption: "\(s.momentIDs.count) of your people have birthdays in it",
                         action: { model.route = .season(s.monthStart) })
    }

    @ViewBuilder private var accessLinks: some View {
        switch ContactsService.shared.access {
        case .denied:
            TextLink(title: "Let Held Dear see your contacts in Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .frame(maxWidth: .infinity)
        case .limited:
            TextLink(title: "Add more people") { model.route = .addBirthday }
                .frame(maxWidth: .infinity)
        default:
            EmptyView()
        }
    }
}
