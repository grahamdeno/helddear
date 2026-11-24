import SwiftUI

/// Finds (story 2.9, approved Nov 21, 2026): every find in the app to browse, newest first, narrowed by who it's
/// for and price. Free. The catalog ships with the app; each picture comes from the find's own shop page, once
/// (FindPictures, Nov 21, 2026). Two columns of pictures, filters on one line, details on tap.
struct FindsView: View {
    @EnvironmentObject var model: AppModel
    @State private var fits: Set<FindFit> = []
    @State private var prices: Set<FindPrice> = []
    @State private var opened: Find?
    @Environment(\.dynamicTypeSize) private var typeSize

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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Brand.space3, alignment: .top),
                                         count: typeSize.isAccessibilitySize ? 1 : 2),
                          spacing: Brand.space5) {
                    ForEach(finds) { find in
                        Button { opened = find } label: { FindCard(find: find) }
                            .buttonStyle(PressStyle())
                            .accessibilityLabel("\(find.name), \(find.maker)\(Self.shownPrice(find).map { ", \($0)" } ?? "")")
                            .accessibilityHint("Opens this find")
                    }
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

    /// The price when there is one; nothing when the shop's page has to say.
    static func shownPrice(_ find: Find) -> String? {
        let p = find.price.trimmingCharacters(in: .whitespaces)
        return p.contains("$") ? p : nil
    }

    /// Who it's for slides on one line; price is one small menu at its start.
    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(FindPrice.allCases, id: \.self) { p in
                        Button { if prices.contains(p) { prices.remove(p) } else { prices.insert(p) } } label: {
                            if prices.contains(p) { Label(p.label, systemImage: "checkmark") } else { Text(p.label) }
                        }
                    }
                    if !prices.isEmpty { Button("Any price") { prices = [] } }
                } label: {
                    HStack(spacing: 6) {
                        Text(prices.count == 1 ? prices.first!.label : prices.isEmpty ? "Any price" : "\(prices.count) prices")
                            .font(.callout.weight(.semibold)).lineLimit(2)
                        Image(systemName: "chevron.down").font(.caption.weight(.bold))
                    }
                    .foregroundStyle(prices.isEmpty ? Brand.ink : Brand.page)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background {
                        if prices.isEmpty { Capsule().strokeBorder(Brand.inkMuted, lineWidth: 1) } else { Capsule().fill(Brand.ink) }
                    }
                    .contentShape(Capsule())
                }
                .accessibilityLabel("Price")
                ForEach(FindFit.allCases, id: \.self) { f in
                    chip(f.label, on: fits.contains(f)) { if fits.contains(f) { fits.remove(f) } else { fits.insert(f) } }
                }
                if !fits.isEmpty || !prices.isEmpty {
                    Button { fits = []; prices = [] } label: {
                        Text("Clear").font(.callout.weight(.semibold)).foregroundStyle(Brand.action).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Brand.space5)
        }
        .padding(.horizontal, -Brand.space5)
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if on { Image(systemName: "checkmark").font(.footnote.weight(.bold)) }
                Text(title).font(.callout.weight(.semibold)).lineLimit(2)
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

/// One find as a picture with its name, maker and price under it. The why and delivery wait for the detail.
struct FindCard: View {
    let find: Find

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FindPicture(find: find)
                .aspectRatio(4 / 5, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Brand.raisedLine, lineWidth: 1) }
                .padding(.bottom, 4)
            Text(find.name).font(Brand.serif(17, relativeTo: .body)).foregroundStyle(Brand.ink)
                .multilineTextAlignment(.leading).lineLimit(2)
            Text([find.maker, FindsView.shownPrice(find)].compactMap { $0 }.joined(separator: " · "))
                .textStyle(.caption, color: Brand.inkMuted).lineLimit(2).multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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
            FindPicture(find: find)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: Brand.space2) {
                Text(find.dependable ? "A dependable pick" : "A find").textStyle(.eyebrow, color: Brand.action)
                Text(find.name).font(Brand.display(36, relativeTo: .largeTitle)).foregroundStyle(Brand.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text([find.maker, FindsView.shownPrice(find)].compactMap { $0 }.joined(separator: " · "))
                    .textStyle(.callout, color: Brand.inkSoft)
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
