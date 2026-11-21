import SwiftUI

/// Finds (story 2.9, approved Nov 21, 2026): every find in the app to browse, newest first, narrowed by who it's
/// for and price. Free. Nothing here talks to the network; the catalog ships with the app.
struct FindsView: View {
    @EnvironmentObject var model: AppModel
    @State private var fits: Set<FindFit> = []
    @State private var prices: Set<FindPrice> = []
    @State private var opened: Find?

    var body: some View {
        let finds = Finds.browse(fits: fits, prices: prices)
        ScrollView {
            VStack(alignment: .leading, spacing: Brand.space4) {
                VStack(alignment: .leading, spacing: Brand.space1) {
                    Text("Finds").textStyle(.title).accessibilityAddTraits(.isHeader)
                    Text("Unusual things from small makers, chosen by hand.")
                        .font(Brand.serif(18, relativeTo: .callout, italic: true)).foregroundStyle(Brand.inkSoft)
                }
                filters
                if finds.isEmpty {
                    Text("Nothing fits those filters yet.").textStyle(.body, color: Brand.inkMuted)
                }
                ForEach(finds) { find in
                    Button { opened = find } label: { FindCard(find: find) }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel("\(find.name), \(find.maker), \(find.price), \(find.arrives)")
                        .accessibilityHint("Opens this find")
                }
            }
            .padding(.horizontal, Brand.space5)
            .padding(.vertical, 8)
        }
        .background(Brand.page.ignoresSafeArea())
        .sheet(item: $opened) { find in
            FindDetail(find: find).environmentObject(model)
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: Brand.space2) {
            FlowLayout(spacing: 8) {
                ForEach(FindFit.allCases, id: \.self) { f in
                    chip(f.label, on: fits.contains(f)) { if fits.contains(f) { fits.remove(f) } else { fits.insert(f) } }
                }
            }
            FlowLayout(spacing: 8) {
                ForEach(FindPrice.allCases, id: \.self) { p in
                    chip(p.label, on: prices.contains(p)) { if prices.contains(p) { prices.remove(p) } else { prices.insert(p) } }
                }
                if !fits.isEmpty || !prices.isEmpty {
                    Button { fits = []; prices = [] } label: {
                        Text("Clear").font(.callout.weight(.semibold)).foregroundStyle(Brand.action).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if on { Image(systemName: "checkmark").font(.footnote.weight(.bold)) }
                Text(title).font(.callout.weight(.semibold)).lineLimit(1)
            }
            .foregroundStyle(on ? Brand.page : Brand.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background { if on { Capsule().fill(Brand.ink) } else { Capsule().strokeBorder(Brand.inkMuted, lineWidth: 1) } }
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}

/// One find as a lighter card.
struct FindCard: View {
    let find: Find

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(find.name).font(Brand.serif(20, relativeTo: .title3)).foregroundStyle(Brand.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Brand.space2)
                Text(find.price).textStyle(.callout, color: Brand.inkSoft).lineLimit(1)
            }
            Text(find.dependable ? "\(find.maker) · A dependable pick" : find.maker)
                .textStyle(.caption, color: Brand.inkMuted)
            Text(find.why).textStyle(.body, color: Brand.inkSoft).multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if !find.arrives.isEmpty {
                Text(find.arrives).textStyle(.caption, color: Brand.inkMuted)
            }
        }
        .padding(Brand.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Brand.raisedLine, lineWidth: 1) }
    }
}

/// A find opened: see it at the shop, or use it for someone's coming day.
struct FindDetail: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let find: Find
    @State private var choosing = false
    @State private var usedFor: String?
    @State private var showLifetime = false

    /// Coming days in the next four months, soonest first, one row per person and day.
    private var upcoming: [Moment] {
        let today = Calendar.current.startOfDay(for: Date())
        let horizon = Calendar.current.date(byAdding: .day, value: 120, to: today) ?? today
        return model.allMoments()
            .filter { $0.person != nil && $0.dueDate >= today && $0.dueDate <= horizon && $0.status != .missed }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        FlowScreen(onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: Brand.space2) {
                Text(find.dependable ? "A dependable pick" : "A find").textStyle(.eyebrow, color: Brand.action)
                Text(find.name).font(Brand.display(36, relativeTo: .largeTitle)).foregroundStyle(Brand.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("\(find.maker) · \(find.price)").textStyle(.callout, color: Brand.inkSoft)
                Text(find.why).font(Brand.serif(19, relativeTo: .body)).foregroundStyle(Brand.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if !find.arrives.isEmpty { Text(find.arrives).textStyle(.caption, color: Brand.inkMuted) }
            }
            if let url = URL(string: find.url) {
                Link("See it at \(find.maker)", destination: url)
                    .font(.callout.weight(.semibold)).foregroundStyle(Brand.action).frame(minHeight: 44)
            }
            if let usedFor {
                Text("Added to \(usedFor).").textStyle(.bodyStrong, color: Brand.ink)
            }
            if choosing {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "Use it for").padding(.bottom, Brand.space2)
                    if upcoming.isEmpty {
                        Text("No days in the next four months.").textStyle(.body, color: Brand.inkMuted)
                    }
                    ForEach(upcoming, id: \.id) { m in
                        OptionRow(title: "\(DisplayName.plain(m.person?.name ?? "")) · \(m.label)",
                                  caption: m.dueDate.formatted(.dateTime.month(.abbreviated).day())) { use(for: m) }
                    }
                }
            }
        } footer: {
            if !choosing && usedFor == nil {
                PrimaryButton(title: "Use for…") { choosing = true }
            } else if usedFor != nil {
                PrimaryButton(title: "Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showLifetime) { LifetimeView() }
    }

    private func use(for m: Moment) {
        let kind: ActKind = find.kinds.contains(.gift) ? .gift : (find.kinds.first ?? .gift)
        let act = model.addPart(to: m, kind: kind, label: nil)
        if model.useFind(find, for: act) {
            usedFor = "\(DisplayName.plain(m.person?.name ?? ""))'s \(m.label.lowercased())"
            choosing = false
        } else {
            showLifetime = true
        }
    }
}
