import SwiftUI
import UIKit

/// The occasion plan (roadmap Epic 2, stories 2.1 to 2.4): one screen of parts for a person's day, each with a step
/// and an owner. Three screens in one cover: the plan, one part, and "Add something". Every rule (words, owners,
/// what's open) is in Domain; this view only draws it.
struct PlanView: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    /// Where the close control goes: a holiday page passes its own; otherwise the plan closes its cover.
    var onClose: (() -> Void)? = nil
    /// Opens straight on "Add something" and closes once something is added (from a person's page).
    var startOnAdd = false

    private enum Screen: Equatable { case plan, part(UUID), add, name, relationship }
    @State private var screen: Screen

    init(moment: Moment, onClose: (() -> Void)? = nil, startOnAdd: Bool = false) {
        self.moment = moment
        self.onClose = onClose
        self.startOnAdd = startOnAdd
        _screen = State(initialValue: startOnAdd ? .add : .plan)
    }
    @State private var newName = ""
    /// Suggestions ticked on "Add something", by title, added together.
    @State private var picked: Set<String> = []

    private var person: Person? { moment.person }
    private var personName: String { person?.name ?? "Someone" }
    private var parts: [Act] { moment.planParts }

    /// The household an owner can be picked from: inner-ring people, other than the person the plan is for.
    private var household: [Person] {
        model.allPeople().filter {
            $0.id != person?.id && Relationship.isHouseholdGiver(relationship: $0.relationship, isInner: $0.ring == .inner)
        }
    }

    var body: some View {
        switch screen {
        case .plan:
            if startOnAdd {
                Color.clear.onAppear { (onClose ?? { model.route = nil })() }
            } else {
                planScreen.onAppear { model.startHolidayPlan(moment) }
            }
        case .part(let id):
            if let act = parts.first(where: { $0.id == id }) {
                PartScreen(act: act, household: household, personName: personName, person: person) { screen = .plan }
            } else {
                Color.clear.onAppear { screen = .plan }
            }
        case .add: addScreen
        case .name: nameScreen
        case .relationship:
            if let person {
                RelationshipPicker(person: person) { screen = .plan }
            } else {
                Color.clear.onAppear { screen = .plan }
            }
        }
    }

    // MARK: Plan

    private func step(_ act: Act) -> String { act.currentStep ?? "open" }
    private func family(_ act: Act) -> PartSteps.Family { PartSteps.family(forKindRaw: act.kindRaw) }
    private func info(_ act: Act) -> (text: String, typed: Bool) {
        PartSteps.displayInfo(kindRaw: act.kindRaw, label: act.label, title: act.title)
    }

    private func ownerText(_ act: Act) -> String {
        let ids = PartOwners.existing(act.ownerIDs, among: household.map(\.id))
        return PartOwners.text(names: household.filter { ids.contains($0.id) }.map(\.name))
    }

    private var days: Int { OccasionDates.daysBetween(Date(), moment.dueDate) }

    private var eyebrow: String {
        var bits = [moment.label, moment.dueDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())]
        if days == 0 { bits.append("TODAY") } else if days == 1 { bits.append("1 DAY") } else if days > 1 { bits.append("\(days) DAYS") }
        return bits.joined(separator: " · ").uppercased()
    }

    private var nudge: PlanNudge.Result {
        PlanNudge.make(parts: parts.map {
            let i = info($0)
            return PlanNudge.Part(name: i.text, typed: i.typed, family: family($0), step: step($0))
        }, daysLeft: days)
    }

    private var planScreen: some View {
        let readiness = PlanReadiness.counts(parts.map { (family: family($0), step: step($0)) })
        let nudge = self.nudge
        return FlowScreen(onClose: onClose ?? { model.route = nil }) {
            Eyebrow(text: eyebrow)
            Text(personName)
                .font(Brand.display(NameSize.title(personName), relativeTo: .largeTitle)).tracking(-1.5)
                .foregroundStyle(Brand.ink)
                .lineLimit(2).minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let line = PlanReadiness.relationLine(relationship: person?.relationship, turning: moment.turning) {
                Text(line).textStyle(.callout, color: Brand.inkMuted).fixedSize(horizontal: false, vertical: true)
            }
            if person != nil && person?.relationship == nil {
                TextLink(title: "Who is \(personName) to you?") { screen = .relationship }
            }
            VStack(alignment: .leading, spacing: Brand.space2) {
                readinessBar
                Text(PlanReadiness.summary(ready: readiness.ready, total: readiness.total, subject: moment.subject))
                    .textStyle(.callout, color: Brand.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            if let note = nudge.note {
                Card { Text(note).textStyle(.body).fixedSize(horizontal: false, vertical: true) }
            }
            VStack(spacing: 0) {
                ForEach(parts, id: \.id) { act in row(act) }
            }
            TextLink(title: "+ Add something") { screen = .add }
        } footer: {
            PrimaryButton(title: nudge.buttonTitle) {
                if let t = nudge.target, parts.indices.contains(t) { screen = .part(parts[t].id) }
            }
            .disabled(!nudge.isEnabled)
            .opacity(nudge.isEnabled ? 1 : 0.45)
        }
    }

    /// One segment per part. Ready is solid, started is a middle tone, not started is the line colour.
    private var readinessBar: some View {
        HStack(spacing: 4) {
            ForEach(parts, id: \.id) { act in
                Rectangle().fill(segmentColor(PartSteps.progress(step: step(act), family: family(act))))
                    .frame(height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private func segmentColor(_ p: PartSteps.Progress) -> Color {
        switch p {
        case .ready: Brand.ink
        case .started: Brand.inkMuted.opacity(0.5)
        case .notStarted: Brand.line
        }
    }

    private func row(_ act: Act) -> some View {
        let ownerNames = household.filter { PartOwners.existing(act.ownerIDs, among: household.map(\.id)).contains($0.id) }.map(\.name)
        let kidsName = act.kind == .kidsMade && act.label == nil ? PartOwners.kidsGiftName(names: ownerNames) : nil
        let name = kidsName ?? info(act).text
        let s = step(act)
        let owner: String = {
            if act.kind == .kidsMade && ownerNames.isEmpty { return "Choose who it's from" }
            return ownerText(act)
        }()
        return Button { screen = .part(act.id) } label: {
            HStack(alignment: .center, spacing: Brand.space3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).textStyle(.bodyStrong).multilineTextAlignment(.leading)
                    let subtitle = kidsName != nil ? (act.note ?? "") : PartOwners.rowSubtitle(owner: owner, note: act.note)
                    if !subtitle.isEmpty {
                        Text(subtitle).textStyle(.caption, color: Brand.inkMuted).multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                StepPill(step: s, family: family(act), date: PartSteps.datedSteps.contains(s) ? act.arrivesBy : nil)
            }
            .padding(.vertical, Brand.space4)
            .frame(minHeight: 64)
            .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(PartOwners.rowLabel(name: name, owner: owner, step: s))
        .accessibilityHint("Opens this part")
    }

    // MARK: Add something

    private var suggestions: [PartSuggestions.Suggestion] {
        PartSuggestions.suggestions(for: moment.type, relationship: person?.relationship)
    }

    private var addScreen: some View {
        let chosen = suggestions.filter { picked.contains($0.title) }
        return FlowScreen {
            TextLink(title: startOnAdd ? "‹ \(personName)" : "‹ \(personName)'s plan") { picked = []; screen = .plan }
            Question(title: "Add something", subtitle: "Pick as many as you like.")
            VStack(spacing: 0) {
                ForEach(suggestions, id: \.title) { s in suggestionRow(s) }
                OptionRow(title: "Something else…") { newName = ""; screen = .name }
            }
        } footer: {
            PrimaryButton(title: chosen.isEmpty ? "Add" : "Add \(chosen.count)") {
                for s in chosen { model.addPart(to: moment, kind: s.kind, label: s.label) }
                picked = []
                screen = .plan
            }
            .disabled(chosen.isEmpty)
            .opacity(chosen.isEmpty ? 0.45 : 1)
        }
    }

    @ViewBuilder private func suggestionRow(_ s: PartSuggestions.Suggestion) -> some View {
        let existing = parts.map { (kindRaw: $0.kindRaw, label: $0.label) }
        let added = PartSuggestions.isAdded(s, parts: existing) && !PartSuggestions.canAddAgain(s)
        let already = PartSuggestions.canAddAgain(s) ? PartSuggestions.count(s, parts: existing) : 0
        if added {
            suggestionLabel(s.title, trailing: "Added", color: Brand.inkMuted)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(s.title), added")
        } else {
            let on = picked.contains(s.title)
            Button {
                if on { picked.remove(s.title) } else { picked.insert(s.title) }
            } label: {
                HStack(spacing: Brand.space3) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.title).textStyle(.bodyStrong).multilineTextAlignment(.leading)
                        if already > 0 {
                            Text("\(already) in the plan. Add another").textStyle(.caption, color: Brand.inkMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(on ? Brand.action : Brand.inkMuted)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, Brand.space4)
                .frame(minHeight: 64)
                .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(s.title)
            .accessibilityValue(on ? "Selected" : "Not selected")
            .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        }
    }

    private func suggestionLabel(_ title: String, trailing: String, color: Color) -> some View {
        HStack(spacing: Brand.space3) {
            Text(title).textStyle(.bodyStrong).multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(trailing).font(.callout.weight(.semibold)).foregroundStyle(color)
        }
        .padding(.vertical, Brand.space4)
        .frame(minHeight: 64)
        .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
        .contentShape(Rectangle())
    }

    private var nameScreen: some View {
        FlowScreen {
            TextLink(title: "‹ Add something") { screen = .add }
            Question(title: "What is it?", subtitle: "A name is enough. You can set the rest on the next screen.")
            LineField(label: "Name", text: $newName, placeholder: "For example, Pajamas", showsDictation: true)
        } footer: {
            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            PrimaryButton(title: "Add") {
                model.addPart(to: moment, kind: .other, label: trimmed)
                screen = .plan
            }
            .disabled(trimmed.isEmpty)
            .opacity(trimmed.isEmpty ? 0.45 : 1)
        }
    }
}

/// The short word at the right of a plan row. The word is always there, so colour is never the only signal.
struct StepPill: View {
    let step: String
    let family: PartSteps.Family
    var date: Date? = nil

    var body: some View {
        let progress = PartSteps.progress(step: step, family: family)
        let word = PartSteps.pillWord(for: step) + (date.map { " " + $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "")
        Text(word)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(progress == .ready ? Brand.page : (progress == .started ? Brand.ink : Brand.inkMuted))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background {
                switch progress {
                case .ready: Capsule().fill(Brand.ink)
                case .started: Capsule().fill(Brand.ringMiddle)
                case .notStarted: Capsule().strokeBorder(Brand.inkMuted, lineWidth: 1)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One part: its note, where it stands, and who it's from. Choosing a step or a person saves right away.
private struct PartScreen: View {
    @EnvironmentObject var model: AppModel
    let act: Act
    /// Everyone an item can be from: the household first, then others in the inner ring.
    let household: [Person]
    let personName: String
    let person: Person?
    /// On a page pushed from Home the back link is in the bar, so the page doesn't draw its own.
    var inNav = false
    let back: () -> Void

    @State private var note = ""
    @State private var name = ""
    @State private var loaded = false
    @State private var showLifetime = false
    @State private var showMore = false
    @State private var showOthers = false
    @State private var noLinkCopied = false
    @State private var confirmRemove = false
    @State private var removed = false
    @FocusState private var noteFocused: Bool
    @FocusState private var nameFocused: Bool

    private var family: PartSteps.Family { PartSteps.family(forKindRaw: act.kindRaw) }
    private var current: String { act.currentStep ?? "open" }
    private var ownerIDs: [UUID] { PartOwners.existing(act.ownerIDs, among: household.map(\.id)) }

    /// The household (a partner and the children); everyone else is under "Someone else" (feedback on build 1017).
    private var core: [Person] {
        household.filter { [.partner, .child].contains(Relationship.group($0.relationship)) }
    }
    private var others: [Person] { household.filter { p in !core.contains { $0.id == p.id } } }

    /// What it is when nothing's been typed: "Gift", or "Gift from Heidi and Nora" once who it's from is set.
    private var autoName: String {
        let names = household.filter { ownerIDs.contains($0.id) }.map { DisplayName.plain($0.name) }
        if act.kind == .kidsMade, let n = PartOwners.kidsGiftName(names: names) { return n }
        return PartSteps.defaultName(forKindRaw: act.kindRaw)
    }

    private var eyebrow: String {
        var bits: [String] = []
        if !personName.isEmpty { bits.append("For \(DisplayName.plain(personName))") }
        if let m = act.moment { bits.append(m.label) }
        bits.append(autoName)
        return bits.joined(separator: " · ")
    }

    var body: some View {
        FlowScreen {
            if !inNav { TextLink(title: "‹ \(personName)'s plan") { save(); back() } }
            VStack(alignment: .leading, spacing: Brand.space1) {
                Eyebrow(text: eyebrow)
                TextField("What is it?", text: $name, axis: .vertical)
                    .lineLimit(1...3)
                    .font(Brand.display(44, relativeTo: .largeTitle))
                    .foregroundStyle(Brand.ink)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onChange(of: nameFocused) { _, focused in if !focused { saveName() } }
                    .accessibilityLabel("What is it?")
                Text("Name it here. The name shows on \(DisplayName.plain(personName))'s page.")
                    .textStyle(.caption, color: Brand.inkMuted)
            }
            // Saved ideas come first on a gift, all of them, so they're there when you need them (feedback on
            // build 1021).
            shelfList
            card("Where it stands") { standsList }
            card("Who it's from", trailing: "Pick any") { ownersList }
            card("Link and note") { linkAndNote }
            findsList
            TextLink(title: "Remove from plan") { confirmRemove = true }
                .padding(.leading, -8)
                .padding(.top, Brand.space2)
        }
        .confirmationDialog("Remove \(name.isEmpty ? autoName : name) from the plan?", isPresented: $confirmRemove,
                            titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                removed = true
                back()
                // After the page has gone, so nothing on screen reads the removed item.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { model.removePart(act) }
            }
        }
        .sheet(isPresented: $showLifetime) { LifetimeView() }
        .onDisappear { if !removed { save() } }
        .onAppear {
            guard !loaded else { return }
            note = act.note ?? ""
            let info = PartSteps.displayInfo(kindRaw: act.kindRaw, label: act.label, title: act.title)
            name = info.typed ? info.text : ""
            loaded = true
        }
    }

    /// A lighter card with a title, like the person page.
    private func card<Content: View>(_ title: String, trailing: String? = nil, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Brand.space3) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(Brand.serif(20, relativeTo: .title3)).foregroundStyle(Brand.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Brand.space2)
                if let trailing { Text(trailing).textStyle(.caption, color: Brand.inkMuted) }
            }
            content()
        }
        .padding(Brand.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Brand.raisedLine, lineWidth: 1) }
    }

    private func save() { saveNote(); saveName() }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let info = PartSteps.displayInfo(kindRaw: act.kindRaw, label: act.label, title: act.title)
        let currentTyped = info.typed ? info.text : ""
        if trimmed != currentTyped { model.setLabel(act, trimmed) }
    }

    private func saveNote() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != (act.note ?? "") { model.setNote(act, trimmed) }
    }

    /// The kind's own statuses, then the rest of the full list under "More" (open by itself when the current status
    /// is one of those).
    private var shownSteps: [String] {
        let more = PartSteps.moreSteps(for: family)
        let expanded = showMore || more.contains(current)
        return PartSteps.steps(for: family) + (expanded ? more : [])
    }

    private var dateBinding: Binding<Date> {
        Binding(get: { act.arrivesBy ?? Calendar.current.startOfDay(for: Date()) },
                set: { act.arrivesBy = Calendar.current.startOfDay(for: $0); model.commit() })
    }

    private func pick(_ step: String) {
        guard model.setStep(act, step) else { showLifetime = true; return }
        if PartSteps.datedSteps.contains(step) && act.arrivesBy == nil {
            act.arrivesBy = Calendar.current.startOfDay(for: Date())
            model.commit()
        }
    }

    private var standsList: some View {
        VStack(alignment: .leading, spacing: Brand.space2) {
            FlowLayout(spacing: 8) {
                ForEach(shownSteps, id: \.self) { step in stepChip(step) }
                if !showMore && !PartSteps.moreSteps(for: family).contains(current) {
                    Button { showMore = true } label: {
                        Text("More statuses").font(.callout.weight(.semibold)).foregroundStyle(Brand.action)
                            .padding(.horizontal, 6).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            if PartSteps.datedSteps.contains(current) {
                DatePicker("\(PartSteps.word(for: current)) on", selection: dateBinding, displayedComponents: .date)
                    .textStyle(.body)
                    .tint(Brand.action)
                    .frame(minHeight: 48)
                    .overlay(alignment: .top) { Rectangle().fill(Brand.raisedLine).frame(height: 1) }
            }
        }
    }

    private func stepChip(_ step: String) -> some View {
        chip(PartSteps.word(for: step), selected: step == current) { pick(step) }
            .accessibilityValue(step == current ? "Selected" : "Not selected")
            .accessibilityHint("Where it stands. One choice.")
    }

    private var ownersList: some View {
        VStack(alignment: .leading, spacing: Brand.space2) {
            FlowLayout(spacing: 8) {
                chip("You", selected: ownerIDs.isEmpty) { model.setOwners(act, PartOwners.you()) }
                ForEach(core, id: \.id) { p in giverChip(p) }
                if showOthers || others.contains(where: { ownerIDs.contains($0.id) }) {
                    ForEach(others, id: \.id) { p in giverChip(p) }
                }
            }
            if !others.isEmpty && !others.contains(where: { ownerIDs.contains($0.id) }) {
                Button { showOthers.toggle() } label: {
                    Text(showOthers ? "Fewer people" : "Someone else…").font(.callout.weight(.semibold)).foregroundStyle(Brand.action)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func giverChip(_ p: Person) -> some View {
        let first = DisplayName.plain(p.name).split(separator: " ").first.map(String.init) ?? DisplayName.plain(p.name)
        return chip(first, selected: ownerIDs.contains(p.id)) {
            model.setOwners(act, PartOwners.toggled(ownerIDs, tapping: p.id))
        }
        .accessibilityLabel(DisplayName.plain(p.name))
    }

    /// The link (what was bought, or where to track it) and the note.
    @ViewBuilder private var linkAndNote: some View {
        let link = act.wishID.flatMap { id in person?.wishes.first { $0.id == id } }?.url.flatMap(URL.init(string:))
        VStack(alignment: .leading, spacing: 0) {
            if let link {
                Link(destination: link) {
                    HStack {
                        Text(link.host() ?? link.absoluteString).textStyle(.body, color: Brand.action).lineLimit(1)
                        Spacer()
                        Text("Open ›").textStyle(.caption, color: Brand.inkMuted)
                    }
                    .frame(minHeight: 48)
                }
                .accessibilityLabel("Open the link, \(link.host() ?? "")")
            }
            Button { pasteLink() } label: {
                HStack {
                    Text(link == nil ? "Paste a link" : "Paste a different link").textStyle(.body)
                    Spacer()
                    Text(noLinkCopied ? "Copy a link first" : "What you ordered, or tracking")
                        .textStyle(.caption, color: noLinkCopied ? Brand.action : Brand.inkMuted)
                }
                .frame(minHeight: 48)
                .overlay(alignment: .top) { if link != nil { Rectangle().fill(Brand.raisedLine).frame(height: 1) } }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            TextField("Add a note, like when it arrives", text: $note, axis: .vertical)
                .lineLimit(1...4)
                .font(Brand.serif(17, relativeTo: .body, italic: true))
                .foregroundStyle(Brand.ink)
                .focused($noteFocused)
                .frame(minHeight: 48, alignment: .leading)
                .overlay(alignment: .top) { Rectangle().fill(Brand.raisedLine).frame(height: 1) }
                .onChange(of: noteFocused) { _, focused in if !focused { saveNote() } }
        }
    }

    /// Reads a link only when one has been copied, so iOS asks only then.
    private func pasteLink() {
        guard UIPasteboard.general.hasURLs, let url = UIPasteboard.general.url else {
            noLinkCopied = true
            return
        }
        noLinkCopied = false
        model.attachLink(url, to: act)
    }

    /// Finds (approved Nov 20, 2026): at most two, from the catalog in the app, fitted to the item, the giver and
    /// what the person loves. Use this makes it the idea; Not for her hides it for good.
    @ViewBuilder private var findsList: some View {
        let _ = model.revision
        if let person, let due = act.moment?.dueDate, act.wishID == nil {
            let finds = Finds.matches(kind: act.kind, fromKids: act.kind == .kidsMade, loves: person.loves,
                                      dismissed: Finds.dismissed(for: person.id))
            if !finds.isEmpty {
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: act.kind == .kidsMade ? "Finds the kids could give" : "A find for \(DisplayName.plain(person.name))")
                    ForEach(finds) { find in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(find.name).textStyle(.bodyStrong)
                            Text(Finds.meta(find, due: due)).textStyle(.caption, color: Brand.inkMuted)
                            Text(find.why).font(Brand.serif(16, relativeTo: .callout)).foregroundStyle(Brand.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: Brand.space3) {
                                Button { if !model.useFind(find, for: act) { showLifetime = true } } label: {
                                    Text("Use this").font(.callout.weight(.semibold)).foregroundStyle(Brand.ink)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .overlay { RoundedRectangle(cornerRadius: Brand.radiusLg).strokeBorder(Brand.ink, lineWidth: 1) }
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PressStyle())
                                .accessibilityLabel("Use \(find.name)")
                                Button { model.dismissFind(find, for: person) } label: {
                                    Text("Not for \(DisplayName.plain(person.name))").font(.callout).foregroundStyle(Brand.action)
                                        .frame(minHeight: 44)
                                }
                                .buttonStyle(PressStyle())
                                .accessibilityLabel("Hide \(find.name) for \(person.name)")
                            }
                            .padding(.top, 4)
                            if let url = URL(string: find.url) {
                                Link("See it at \(find.maker)", destination: url)
                                    .font(.callout).foregroundStyle(Brand.action).frame(minHeight: 44)
                            }
                        }
                        .padding(Brand.space4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Brand.raised, in: RoundedRectangle(cornerRadius: Brand.radiusLg, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: Brand.radiusLg, style: .continuous).strokeBorder(Brand.raisedLine, lineWidth: 1) }
                    }
                }
            }
        }
    }

    /// The shelf feeds the gift (roadmap 2.5): every saved idea for this person, one tap to make one the idea.
    /// With none saved yet, one line to save the first.
    @ViewBuilder private var shelfList: some View {
        let wishes = person?.openWishes ?? []
        let giftKinds: [ActKind] = [.gift, .fromSanta, .stocking, .kidsMade]
        if let person, giftKinds.contains(act.kind) {
            let first = DisplayName.plain(person.name)
            card("\(first)'s saved ideas", trailing: wishes.isEmpty ? nil : "\(wishes.count)") {
                if wishes.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Nothing saved for \(first) yet. When you see something \(first) would like, save it and it comes up here at every day.")
                            .textStyle(.caption, color: Brand.inkMuted).fixedSize(horizontal: false, vertical: true)
                        TextLink(title: "Save an idea for \(first)") { save(); model.route = .addWish(person.id) }
                            .padding(.leading, -8)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(wishes, id: \.id) { wish in
                            let chosen = act.wishID == wish.id
                            Button { if !model.pickWish(wish, for: act) { showLifetime = true } } label: {
                                HStack(spacing: Brand.space3) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(wish.text).textStyle(chosen ? .bodyStrong : .body).multilineTextAlignment(.leading)
                                        Text(wish.savedLine).textStyle(.caption, color: Brand.inkMuted)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(chosen ? "Chosen" : "Use this").font(.callout.weight(.semibold))
                                        .foregroundStyle(chosen ? Brand.inkMuted : Brand.action)
                                }
                                .padding(.vertical, Brand.space3)
                                .frame(minHeight: 56)
                                .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressStyle())
                            .disabled(chosen)
                            .accessibilityLabel(chosen ? "\(wish.text), chosen" : "Use \(wish.text)")
                        }
                        TextLink(title: "Save another") { save(); model.route = .addWish(person.id) }
                            .padding(.leading, -8)
                    }
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if selected { Image(systemName: "checkmark").font(.footnote.weight(.bold)) }
                Text(title).font(.callout.weight(.semibold)).lineLimit(1)
            }
            .foregroundStyle(selected ? Brand.page : Brand.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background {
                if selected { Capsule().fill(Brand.ink) } else { Capsule().strokeBorder(Brand.inkMuted, lineWidth: 1) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}


/// One item's page, pushed from a person's page: its note, where it stands, its link and who it's from.
struct ItemView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let act: Act

    var body: some View {
        let person = act.moment?.person
        PartScreen(act: act, household: model.household(for: person), personName: person?.name ?? "", person: person,
                   inNav: true) { dismiss() }
    }
}

/// "Who is Ben to you?" One tap sets the relationship, which shapes suggestions (roadmap 1.6).
struct RelationshipPicker: View {
    @EnvironmentObject var model: AppModel
    let person: Person
    var backTitle: String? = nil
    /// Off on a pushed page (the back link is in the bar) and in Add someone (the person is already saved).
    var showsBack = true
    let done: () -> Void
    @State private var showMore = false

    private func isSelected(_ word: String) -> Bool {
        person.relationship?.caseInsensitiveCompare(word) == .orderedSame
    }

    private var moreOpen: Bool { showMore || Relationship.moreChoices.contains(where: isSelected) }

    var body: some View {
        let name = DisplayName.plain(person.name)
        FlowScreen {
            if showsBack { TextLink(title: "‹ " + (backTitle ?? "\(name)'s plan")) { done() } }
            Question(title: "Who is \(name) to you?", subtitle: "So Held Dear can suggest what families usually plan.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Relationship.mainChoices, id: \.self) { word in
                    tile(word, selected: isSelected(word)) { pick(word) }
                }
                tile("Someone else…", selected: moreOpen) { showMore.toggle() }
                    .accessibilityHint("Shows more choices")
            }
            if moreOpen {
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Someone else")
                    FlowLayout(spacing: 8) {
                        ForEach(Relationship.moreChoices, id: \.self) { word in chip(word) }
                    }
                }
            }
        } footer: {
            TextLink(title: "Skip for now") { done() }
        }
    }

    private func pick(_ word: String) {
        model.setRelationship(person, word)
        done()
    }

    private func tile(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.title3.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                .foregroundStyle(selected ? Brand.page : Brand.ink)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(selected ? Brand.ink : Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous)
                        .strokeBorder(selected ? Brand.ink : Brand.line, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func chip(_ word: String) -> some View {
        let selected = isSelected(word)
        return Button { pick(word) } label: {
            Text(word).font(.callout.weight(.semibold))
                .foregroundStyle(selected ? Brand.page : Brand.ink)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background {
                    if selected { Capsule().fill(Brand.ink) } else { Capsule().strokeBorder(Brand.inkMuted, lineWidth: 1) }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// "Who is Ben to you?" as a page pushed from the person's page.
struct RelationshipPage: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person

    var body: some View {
        RelationshipPicker(person: person, showsBack: false) { dismiss() }
    }
}
