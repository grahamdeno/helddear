import SwiftUI
import UIKit

/// Planning one item, a question at a time (Graham, Nov 22, 2026): do you know what you'll do (if not, suggestions),
/// how, the follow-up that changes a date, then one screen with the place or link and the dates worked out. The
/// rules are in Domain/ItemFlow.swift. "See the details" opens the full item page at any point.
struct ItemFlowView: View {
    @EnvironmentObject var model: AppModel
    let act: Act
    let moment: Moment
    let person: Person?
    let personName: String
    var inNav: Bool
    let back: () -> Void
    let showDetails: () -> Void

    private enum Step: Equatable { case know, ideas, how, finish }
    @State private var step: Step = .know
    @State private var path: [ItemFlow.Path] = []
    @State private var title = ""
    @State private var link = ""
    @State private var placeName = ""
    @State private var chosenPlace: Place?
    @State private var note = ""
    @State private var showLifetime = false
    @State private var started = false

    private var kind: ActKind { act.kind }
    private var name: String { DisplayName.plain(personName) }
    private var canShipToThem: Bool {
        guard let person else { return false }
        return person.mailingAddress != nil || ContactsService.shared.mailAddress(contactID: person.contactID) != nil
    }
    private var itemName: String { PartSteps.defaultName(forKindRaw: act.kindRaw).lowercased() }

    var body: some View {
        Group {
            switch step {
            case .know: knowStep
            case .ideas: ideasStep
            case .how: howStep
            case .finish: finishStep
            }
        }
        .animation(.easeOut(duration: 0.2), value: step)
        .onAppear {
            guard !started else { return }
            started = true
            if !ItemFlow.asksIfKnown(kind) { advance() }
        }
        .sheet(isPresented: $showLifetime) { LifetimeView() }
    }

    private var header: some View {
        Group { if !inNav { TextLink(title: "‹ \(personName)'s plan") { back() } } }
    }

    private var detailsLink: some View {
        TextLink(title: "See the \(itemName)'s details") { showDetails() }.padding(.leading, -8)
    }

    // MARK: Do you know what you'll do?

    private var knowStep: some View {
        FlowScreen {
            header
            Question(title: ItemFlow.knowQuestion(kind: kind, name: name), subtitle: dueLine, style: .title)
            VStack(spacing: 0) {
                OptionRow(title: "I have an idea", caption: "Plan how and when") { advance() }
                OptionRow(title: "Not yet", caption: "See ideas for \(name)") { step = .ideas }
            }
            detailsLink
        }
    }

    private var dueLine: String {
        "\(moment.label) · \(moment.dueDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))"
    }

    // MARK: Suggestions

    private var finds: [Find] {
        Finds.matches(kind: kind, fromKids: kind == .kidsMade, loves: person?.loves ?? [], dismissed: [], limit: 4)
    }

    private var places: [Place] {
        Places.hasWhereFrom(kind) ? Array(Places.offered(PlaceStore.shared.all, kindRaw: act.kindRaw, personZip: nil).prefix(4)) : []
    }

    private var savedIdeas: [Wish] {
        [.gift, .stocking, .fromSanta, .kidsMade].contains(kind) ? Array((person?.openWishes ?? []).prefix(4)) : []
    }

    private var ideasStep: some View {
        FlowScreen(onClose: { step = .know }) {
            Question(title: "Ideas for \(name)", subtitle: (person?.loves.isEmpty ?? true) ? "Add what \(name) loves on their page and these get better." : "Picked for what \(name) loves.", style: .title)
            if !savedIdeas.isEmpty {
                Eyebrow(text: "You saved")
                VStack(spacing: 0) {
                    ForEach(savedIdeas, id: \.id) { w in
                        Button { useWish(w) } label: {
                            HStack { WishPreview(wish: w).frame(maxWidth: .infinity, alignment: .leading); ChevronDisc() }
                                .padding(.vertical, Brand.space2)
                                .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            }
            if !places.isEmpty {
                Eyebrow(text: "Places you've used")
                VStack(spacing: 0) {
                    ForEach(places) { p in OptionRow(title: p.name, caption: p.link.flatMap { URL(string: $0)?.host() } ?? "Used before") { usePlace(p) } }
                }
            }
            if !finds.isEmpty {
                Eyebrow(text: "Finds")
                VStack(spacing: 0) {
                    ForEach(finds) { f in
                        OptionRow(title: f.name, caption: [f.maker, FindsView.shownPrice(f)].compactMap { $0 }.joined(separator: " · ") + " · " + f.why) {
                            useFind(f)
                        }
                    }
                }
            }
            if savedIdeas.isEmpty && places.isEmpty && finds.isEmpty {
                Text("Nothing to suggest yet. Save ideas for \(name) from any app with the share sheet, or open Finds.")
                    .textStyle(.body, color: Brand.inkMuted)
            }
            TextLink(title: "None of these, I'll choose") { advance() }.padding(.leading, -8)
        }
    }

    private func useWish(_ w: Wish) {
        act.wishID = w.id
        title = String(w.text.prefix(80))
        link = w.url ?? ""
        path = w.url != nil ? [.online] : [.local]
        continueAfterPrefill()
    }

    private func useFind(_ f: Find) {
        title = f.name
        link = f.url
        switch kind {
        case .cake: path = [.buy, .online]
        case .flowers: path = [.delivered, .online]
        case .dinner, .theDay: path = [.outing]
        case .kidsMade, .other: path = []
        default: path = [.online]
        }
        continueAfterPrefill()
    }

    private func usePlace(_ p: Place) {
        chosenPlace = p
        switch kind {
        case .cake: path = [.buy, .local]
        case .flowers: path = [.delivered, .local]
        default: path = [.restaurant, .book]
        }
        continueAfterPrefill()
    }

    private func continueAfterPrefill() {
        step = ItemFlow.question(kind: kind, path: path, name: name, canShipToThem: canShipToThem) == nil ? .finish : .how
    }

    // MARK: How, and the follow-up

    private func advance() {
        step = ItemFlow.question(kind: kind, path: path, name: name, canShipToThem: canShipToThem) == nil ? .finish : .how
    }

    @ViewBuilder private var howStep: some View {
        if let q = ItemFlow.question(kind: kind, path: path, name: name, canShipToThem: canShipToThem) {
            FlowScreen(onClose: {
                if path.isEmpty { step = ItemFlow.asksIfKnown(kind) ? .know : .know } else { path.removeLast() }
            }) {
                Question(title: q.title, subtitle: dueLine, style: .title)
                VStack(spacing: 0) {
                    ForEach(q.options, id: \.path.rawValue) { o in
                        OptionRow(title: o.title, caption: o.caption) {
                            path.append(o.path)
                            advance()
                        }
                    }
                }
                detailsLink
            }
        }
    }

    // MARK: The last screen

    private var finish: ItemFlow.Finish { ItemFlow.finish(kind: kind, path: path) }
    private var dates: [(label: String, date: Date)] { ItemFlow.dates(finish, due: moment.dueDate, now: Date()) }

    private var finishStep: some View {
        FlowScreen(onClose: {
            if !path.isEmpty { path.removeLast() }
            step = path.isEmpty ? .know : .how
        }) {
            Question(title: title.isEmpty ? "\(name)'s \(itemName)" : title, subtitle: dates.isEmpty ? dueLine : ItemFlow.summary(dates), style: .title)
            switch finish.ask {
            case .link(let label):
                field(label, text: $link, placeholder: "Paste a link")
                TextLink(title: "Paste") { if let s = UIPasteboard.general.string { link = s.trimmingCharacters(in: .whitespacesAndNewlines) } }
                    .padding(.leading, -8)
            case .place:
                let offered = Places.offered(PlaceStore.shared.all, kindRaw: act.kindRaw, personZip: nil)
                if !offered.isEmpty {
                    Eyebrow(text: "Where")
                    FlowLayout(spacing: 8) {
                        ForEach(offered) { p in
                            let on = chosenPlace?.id == p.id
                            Button { chosenPlace = on ? nil : p } label: {
                                Text(p.name).font(.callout.weight(.semibold))
                                    .foregroundStyle(on ? Brand.page : Brand.ink)
                                    .padding(.horizontal, 14).frame(minHeight: 44)
                                    .background { if on { Capsule().fill(Brand.ink) } else { Capsule().strokeBorder(Brand.inkMuted, lineWidth: 1) } }
                            }
                            .buttonStyle(PressStyle())
                        }
                    }
                }
                field(offered.isEmpty ? "Where" : "Or somewhere new", text: $placeName, placeholder: "The name")
            case .note(let label):
                field(label, text: $title, placeholder: "One line is plenty")
            }
            field("Note", text: $note, placeholder: "Anything to remember, like flavor or size")
            if !dates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Dates")
                    ForEach(dates, id: \.label) { d in
                        Text("\(d.label) \(d.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))").textStyle(.body)
                    }
                }
            }
            TextLink(title: alreadyTitle) { save(step: alreadyStep) }.padding(.leading, -8)
        } footer: {
            PrimaryButton(title: "Save the plan") { save(step: finish.step) }
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: Brand.space1) {
            Eyebrow(text: label)
            TextField(placeholder, text: text)
                .textStyle(.body)
                .padding(.horizontal, Brand.space4).frame(minHeight: 52)
                .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
        }
    }

    /// "Already ordered", "Already booked", "Already bought": for when it's done before the plan.
    private var alreadyStep: String {
        switch PartSteps.family(forKindRaw: act.kindRaw) {
        case .orderAhead: "ordered"
        case .day: "booked"
        case .make: "making"
        case .buy: "bought"
        default: "ready"
        }
    }

    private var alreadyTitle: String {
        switch alreadyStep {
        case "ordered": "I've already ordered it"
        case "booked": "It's already booked"
        case "making": "They've already started"
        case "bought": "I've already got it"
        default: "It's already done"
        }
    }

    private func save(step newStep: String) {
        guard model.setStep(act, newStep) else { showLifetime = true; return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty { act.title = trimmedTitle }
        let url = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty, act.wishID == nil, let person, url.lowercased().hasPrefix("http") {
            model.addWish(to: person, text: trimmedTitle.isEmpty ? (URL(string: url)?.host() ?? url) : trimmedTitle, url: url)
            act.wishID = person.wishes.first { $0.url == url }?.id
        }
        let newPlace = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newPlace.isEmpty {
            PlaceStore.shared.choose(Place(kindRaw: act.kindRaw, name: newPlace), for: act.id)
        } else if let chosenPlace {
            PlaceStore.shared.choose(chosenPlace, for: act.id)
        }
        let summary = ItemFlow.summary(dates)
        let extra = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = [summary, extra].filter { !$0.isEmpty }
        if !lines.isEmpty { act.note = lines.joined(separator: "\n") }
        if let arrives = dates.first(where: { $0.label == "Arrives by" })?.date { act.arrivesBy = arrives }
        model.save()
        showDetails()
    }
}
