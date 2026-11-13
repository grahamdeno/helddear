import SwiftUI
import UIKit

/// "Never stuck on what to give" (decided Nov 13, 2026).
/// Ideas for one person's day: what the user saved to their shelf, ideas written on this iPhone from what the user
/// knows about them, and a few the kids could give. Pick one, open the shop or search the web in Safari, then say
/// when it arrives. No new servers or APIs: nothing here talks to the network on its own.
struct IdeasFlow: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    @State private var path: [IdeaItem] = []

    var body: some View {
        NavigationStack(path: $path) {
            IdeasList(moment: moment) { path.append($0) }
                .navigationDestination(for: IdeaItem.self) { item in
                    IdeaDetail(moment: moment, item: item)
                }
                .toolbar { CloseToolbar { model.route = nil } }
        }
        .tint(Brand.ink)
    }
}

/// One idea, wherever it came from.
struct IdeaItem: Hashable, Identifiable {
    enum Source: Hashable { case shelf, heldDear, kids }
    var id: String { "\(source)-\(title)" }
    var source: Source
    var title: String
    var why: String?
    var url: String?
    var imageFile: String?
    var wishID: UUID?
}

// MARK: The list

struct IdeasList: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    var open: (IdeaItem) -> Void
    @State private var found: [IdeaItem] = []
    @State private var kids: [IdeaItem] = []
    @State private var loading = false
    @State private var loadingKids = false
    @State private var note: String?

    private var name: String { moment.person?.name ?? "" }

    private var shelf: [IdeaItem] {
        (moment.person?.openWishes ?? []).map {
            IdeaItem(source: .shelf, title: $0.text, why: $0.savedLine, url: $0.url, imageFile: $0.imageFile, wishID: $0.id)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(name) · \(OccasionDates.shortDate(moment.dueDate)) · \(OccasionDates.countdown(to: moment.dueDate, from: Date()))")
                    .textStyle(.eyebrow)
                Text("Ideas for \(name)").font(Brand.display(42)).tracking(-0.8).foregroundStyle(Brand.ink)
                    .padding(.top, Brand.space2)
                    .accessibilityAddTraits(.isHeader)
                Text(subline).font(Brand.serif(18, relativeTo: .callout, italic: true)).foregroundStyle(Brand.inkSoft)
                    .padding(.top, 2)

                if !shelf.isEmpty {
                    section("From your shelf")
                    ForEach(shelf) { row($0) }
                }

                section("Ideas for \(name)")
                if OnDeviceIdeas.isAvailable {
                    if loading && found.isEmpty { thinking("Thinking about \(name)…") }
                    ForEach(found) { row($0) }
                    if !found.isEmpty {
                        TextLink(title: loading ? "Thinking…" : "Different ideas") { Task { await loadFound() } }
                            .disabled(loading).padding(.leading, -8).padding(.top, Brand.space2)
                    }
                } else {
                    Text(OnDeviceIdeas.unavailableReason ?? "").textStyle(.callout, color: Brand.inkMuted)
                        .padding(.vertical, Brand.space3)
                }
                if moment.person?.loves.isEmpty ?? true {
                    Button { model.route = .person(moment.person?.id ?? UUID()) } label: {
                        Text("Tell Held Dear what \(name) loves and the ideas get much better.")
                            .font(.callout.weight(.medium)).foregroundStyle(Brand.action).multilineTextAlignment(.leading)
                    }
                    .padding(.top, Brand.space3)
                }

                if OnDeviceIdeas.isAvailable {
                    section("Something the kids could give")
                    if kids.isEmpty {
                        if loadingKids { thinking("Thinking…") } else {
                            TextLink(title: "Show ideas for the kids") { Task { await loadKids() } }.padding(.leading, -8)
                        }
                    }
                    ForEach(kids) { row($0) }
                }

                Text("Saw something somewhere? Share it to Held Dear from Safari or any app, and it lands on \(name)'s shelf.")
                    .textStyle(.caption, color: Brand.inkMuted)
                    .padding(.top, Brand.space6)
                if let note { Text(note).textStyle(.caption, color: Brand.inkMuted).padding(.top, Brand.space2) }
            }
            .padding(.horizontal, Brand.space5)
            .padding(.bottom, Brand.space6)
        }
        .background(Brand.page.ignoresSafeArea())
        .task { if found.isEmpty && OnDeviceIdeas.isAvailable { await loadFound() } }
    }

    private var subline: String {
        let what = moment.countLine.map { "For " + $0.prefix(1).lowercased() + $0.dropFirst() } ?? "For \(moment.type.label.lowercased())"
        let order = OccasionDates.shortDate(GiftTiming.suggestedArrival(due: moment.dueDate, now: Date()))
        return "\(what) · aim to have it by \(order)"
    }

    private func section(_ title: String) -> some View {
        Text(title).textStyle(.eyebrow).padding(.top, Brand.space6).padding(.bottom, Brand.space2)
    }

    private func thinking(_ text: String) -> some View {
        HStack(spacing: Brand.space3) {
            ProgressView()
            Text(text).textStyle(.callout, color: Brand.inkMuted)
        }
        .padding(.vertical, Brand.space3)
    }

    private func row(_ item: IdeaItem) -> some View {
        Button { open(item) } label: {
            HStack(alignment: .top, spacing: Brand.space4) {
                IdeaThumb(item: item, side: 72)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(Brand.serif(19, relativeTo: .headline)).foregroundStyle(Brand.ink)
                        .multilineTextAlignment(.leading).lineLimit(3)
                    if let why = item.why {
                        Text(why).font(.footnote).foregroundStyle(Brand.inkSoft).multilineTextAlignment(.leading).lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Brand.inkMuted)
                    .padding(.top, 6)
            }
            .padding(.vertical, Brand.space3)
            .overlay(alignment: .top) { Rectangle().fill(Brand.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func facts() -> PersonFacts? { moment.person.map { PersonFacts(person: $0, moment: moment) } }

    private func loadFound() async {
        guard let f = facts() else { return }
        loading = true
        defer { loading = false }
        do {
            found = try await OnDeviceIdeas.gifts(for: f).map { IdeaItem(source: .heldDear, title: $0.title, why: $0.why) }
            note = nil
        } catch {
            note = "Couldn't think of ideas right now. Try again in a moment."
        }
    }

    private func loadKids() async {
        guard let f = facts() else { return }
        loadingKids = true
        defer { loadingKids = false }
        kids = ((try? await OnDeviceIdeas.kidsGifts(for: f)) ?? []).map { IdeaItem(source: .kids, title: $0.title, why: $0.why) }
    }
}

struct IdeaThumb: View {
    let item: IdeaItem
    let side: CGFloat

    var body: some View {
        ZStack {
            Brand.card
            if let image = PhotoStore.load(item.imageFile) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: icon).font(.system(size: side * 0.3, weight: .light)).foregroundStyle(Brand.inkMuted)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
        .accessibilityHidden(true)
    }

    private var icon: String {
        switch item.source {
        case .shelf: item.url == nil ? "bookmark" : "link"
        case .heldDear: "sparkles"
        case .kids: "scissors"
        }
    }
}

// MARK: One idea

struct IdeaDetail: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openURL) private var openURL
    let moment: Moment
    let item: IdeaItem
    @State private var choosing = false

    private var name: String { moment.person?.name ?? "" }

    var body: some View {
        if choosing {
            ArrivalStep(moment: moment, item: item)
        } else {
            FlowScreen(onClose: { model.route = nil }) {
                if item.imageFile != nil {
                    IdeaThumb(item: item, side: 120).frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Text(sourceLabel).textStyle(.eyebrow, color: Brand.action)
                    Text(item.title).font(Brand.display(34)).tracking(-0.5).foregroundStyle(Brand.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let why = item.why {
                        Text(why).font(Brand.serif(19, relativeTo: .body)).foregroundStyle(Brand.inkSoft)
                    }
                    if let host = item.url.flatMap(URL.init(string:))?.host() {
                        Text(host.replacingOccurrences(of: "www.", with: "")).textStyle(.caption, color: Brand.inkMuted)
                    }
                }
            } footer: {
                PrimaryButton(title: item.url != nil ? "Open the shop" : "Search the web for it") { openShop() }
                TextLink(title: "I'm getting this for \(name)") { choosing = true }
            }
        }
    }

    private var sourceLabel: String {
        switch item.source {
        case .shelf: "From your shelf"
        case .heldDear: "An idea for \(name)"
        case .kids: "From the kids"
        }
    }

    private func openShop() {
        if let s = item.url, let url = URL(string: s) { openURL(url); return }
        var c = URLComponents(string: "https://www.google.com/search")!
        c.queryItems = [URLQueryItem(name: "q", value: "\(item.title) gift")]
        if let url = c.url { openURL(url) }
    }
}

/// One decision: when will it arrive? Then it's the plan, done, and Home shows "Arrives by …".
struct ArrivalStep: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    let item: IdeaItem
    @State private var arrives = Date()
    @State private var saved = false

    private var name: String { moment.person?.name ?? "" }

    var body: some View {
        if saved { done } else { ask }
    }

    private var ask: some View {
        FlowScreen(onClose: { model.route = nil }) {
            Question(title: "When will it arrive?", subtitle: "Held Dear keeps the date with \(name)'s day.")
            DatePicker("Arrives by", selection: $arrives, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.graphical).tint(Brand.action)
        } footer: {
            PrimaryButton(title: "I ordered it") {
                let wish = item.wishID.flatMap { id in moment.person?.wishes.first { $0.id == id } }
                model.markOrdered(moment, title: item.title, url: item.url, wish: wish, arrivesBy: arrives)
                saved = true
            }
        }
        .onAppear { arrives = GiftTiming.suggestedArrival(due: moment.dueDate, now: Date()) }
    }

    private var done: some View {
        FlowScreen(onClose: { model.route = nil }) {
            VStack(alignment: .leading, spacing: Brand.space2) {
                Text("\(name) · \(OccasionDates.shortDate(moment.dueDate))").textStyle(.eyebrow)
                Text("Ordered.").font(Brand.display(52)).foregroundStyle(Brand.ink)
                Text("Arrives by \(arrives.formatted(.dateTime.month(.wide).day())).")
                    .font(Brand.display(24, relativeTo: .title3, italic: true)).foregroundStyle(Brand.inkSoft)
            }
            VStack(alignment: .leading, spacing: 0) {
                step("Ordered", item.title, on: true)
                step("Arrives", "By \(OccasionDates.shortDate(arrives))", on: false)
                step("\(name)'s day", moment.dueDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()), on: false, last: true)
            }
            .padding(.top, Brand.space4)
        } footer: {
            PrimaryButton(title: "Done") { model.route = nil }
            if OccasionDates.daysBetween(Date(), moment.dueDate) >= 6 {
                TextLink(title: "Add a card, mailed in pen · $6.99") { model.route = .moment(moment.id, .mailCard) }
            }
        }
    }

    private func step(_ title: String, _ sub: String, on: Bool, last: Bool = false) -> some View {
        HStack(alignment: .top, spacing: Brand.space3) {
            VStack(spacing: 0) {
                Circle().fill(on ? Brand.action : Color.clear).overlay(Circle().stroke(on ? Brand.action : Brand.inkMuted, lineWidth: 2))
                    .frame(width: 12, height: 12).padding(.top, 4)
                if !last { Rectangle().fill(Brand.line).frame(width: 2, height: 40) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textStyle(.bodyStrong, color: on ? Brand.ink : Brand.inkMuted)
                Text(sub).textStyle(.caption, color: Brand.inkMuted).lineLimit(2)
            }
        }
    }
}
