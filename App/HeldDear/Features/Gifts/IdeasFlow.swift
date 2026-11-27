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
                    // A pushed idea gets the same named back link as every other page; no second close.
                    IdeaDetail(moment: moment, item: item)
                        .backLink("Ideas")
                }
                .toolbar { CloseToolbar { model.route = nil } }
                .plainBar()
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
    @State private var editingLoves = false

    private var name: String { moment.person?.name ?? "" }

    private var shelf: [IdeaItem] {
        (moment.person?.openWishes ?? []).map {
            IdeaItem(source: .shelf, title: LinkPreviews.isOnlyALink($0.text) ? (LinkPreviews.link(in: $0.text).map(LinkPreviews.shortName) ?? $0.text) : $0.text, why: $0.savedLine, url: $0.url, imageFile: $0.imageFile, wishID: $0.id)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // One calm page (Graham, Nov 22, 2026): one line for the date, saved ideas first, one card with one
                // oxblood button when nothing's here yet, and the kids only for someone they'd give to.
                Text("Ideas for \(name)").font(Brand.display(42)).tracking(-0.8).foregroundStyle(Brand.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(subline).font(Brand.serif(18, relativeTo: .callout, italic: true)).foregroundStyle(Brand.inkSoft)
                    .padding(.top, 2)

                if !shelf.isEmpty {
                    section("Saved for \(name)")
                    ForEach(shelf) { row($0) }
                }
                if !found.isEmpty {
                    section("Ideas for \(name)")
                    ForEach(found) { row($0) }
                }
                if !kids.isEmpty {
                    section("From the kids")
                    ForEach(kids) { row($0) }
                }

                startCard.padding(.top, Brand.space6)

                Text("Or share a link to Held Dear from Safari or any app.")
                    .textStyle(.caption, color: Brand.inkMuted)
                    .padding(.top, Brand.space4)
                if let note { Text(note).textStyle(.caption, color: Brand.inkMuted).padding(.top, Brand.space2) }
            }
            .padding(.horizontal, Brand.space5)
            .padding(.bottom, Brand.space6)
        }
        .background(Brand.page.ignoresSafeArea())
        .sheet(isPresented: $editingLoves, onDismiss: {
            // Suggestions right after, with whatever was added (or without, if nothing was).
            Task { await loadFound() }
        }) {
            if let person = moment.person { PortraitEditor(person: person).presentationDetents([.large]).environmentObject(model) }
        }
    }

    /// What they love, edited right here (Graham, Nov 22, 2026: the link used to drop him on the person's page with no
    /// guidance). Once saved, suggestions come straight back, now using what was added.
    private func openLoves() { editingLoves = true }

    /// "Turns 10 on Feb 18 · have it by Feb 13": the day and the order-by in one line.
    private var subline: String {
        let day = OccasionDates.shortDate(moment.dueDate)
        let what = moment.countLine.map { "\($0) on \(day)" } ?? "\(moment.label) on \(day)"
        let order = OccasionDates.shortDate(GiftTiming.suggestedArrival(due: moment.dueDate, now: Date()))
        return "\(what) · have it by \(order)"
    }

    private var lovesEmpty: Bool { moment.person?.loves.isEmpty ?? true }

    private var kidsOffered: Bool {
        guard let p = moment.person else { return false }
        return Relationship.kidsCouldGive(relationship: p.relationship, isInner: p.ring == .inner)
    }

    /// The one place to start: suggest (asking what they love first, in place, when nothing's saved), or save one.
    @ViewBuilder private var startCard: some View {
        VStack(alignment: .leading, spacing: Brand.space3) {
            // First-use tips (story 4.1): what ideas are for; then, once one is saved, sharing from other apps.
            TipLine(FirstUseTips.pick([
                (.shareIdeas, !FirstUseTips.shouldShow(.ideas) && model.allPeople().contains { !$0.wishes.isEmpty }),
                (.ideas, true),
            ]))
            if shelf.isEmpty && found.isEmpty {
                Text("Nothing saved yet.").textStyle(.headline)
            }
            if OnDeviceIdeas.isAvailable {
                if loading {
                    thinking("Thinking about \(name)…")
                } else {
                    PrimaryButton(title: found.isEmpty ? "Suggest ideas" : "Different ideas") {
                        if lovesEmpty && found.isEmpty { openLoves() } else { Task { await loadFound() } }
                    }
                    Text(lovesEmpty && found.isEmpty ? "First, what does \(name) love? Ideas are written on this iPhone; nothing leaves it."
                                                     : "Written on this iPhone from what you saved. Nothing leaves it.")
                        .textStyle(.caption, color: Brand.inkMuted)
                }
            } else {
                Text(OnDeviceIdeas.unavailableReason ?? "").textStyle(.callout, color: Brand.inkMuted)
            }
            TextLink(title: "Save an idea") { model.route = .addWish(moment.person?.id ?? UUID()) }
                .padding(.leading, -8)
            if OnDeviceIdeas.isAvailable && kidsOffered && kids.isEmpty {
                if loadingKids { thinking("Thinking…") } else {
                    TextLink(title: "Ideas the kids could give") { Task { await loadKids() } }.padding(.leading, -8)
                }
            }
        }
        .padding(Brand.space5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
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
            FlowScreen {
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
        FlowScreen {
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
        FlowScreen {
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
            if OccasionDates.daysBetween(Date(), moment.dueDate) >= 6 && AppFeatures.mailedCards {
                TextLink(title: "Add a card, mailed in pen · \(MailedCards.displayPrice)") { model.route = .moment(moment.id, .mailCard) }
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
