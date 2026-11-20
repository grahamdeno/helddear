import SwiftUI

/// The occasion plan (roadmap Epic 2, stories 2.1 to 2.4): one screen of parts for a person's day, each with a step
/// and an owner. Three screens in one cover: the plan, one part, and "Add something". Every rule (words, owners,
/// what's open) is in Domain; this view only draws it.
struct PlanView: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    /// Where the close control goes: a holiday page passes its own; otherwise the plan closes its cover.
    var onClose: (() -> Void)? = nil

    private enum Screen: Equatable { case plan, part(UUID), add, name, relationship }
    @State private var screen: Screen = .plan
    @State private var newName = ""

    private var person: Person? { moment.person }
    private var personName: String { person?.name ?? "Someone" }
    private var parts: [Act] { moment.planParts }

    /// The household an owner can be picked from: inner-ring people, other than the person the plan is for.
    private var household: [Person] {
        model.allPeople().filter { $0.ring == .inner && $0.id != person?.id }
    }

    var body: some View {
        switch screen {
        case .plan: planScreen.onAppear { model.startHolidayPlan(moment) }
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
        var bits = [moment.type.label, moment.dueDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())]
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
                .font(Brand.display(72, relativeTo: .largeTitle)).tracking(-1.5)
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
        let name = info(act).text
        let owner = ownerText(act)
        let s = step(act)
        return Button { screen = .part(act.id) } label: {
            HStack(alignment: .center, spacing: Brand.space3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).textStyle(.bodyStrong).multilineTextAlignment(.leading)
                    Text(PartOwners.rowSubtitle(owner: owner, note: act.note))
                        .textStyle(.caption, color: Brand.inkMuted).multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                StepPill(step: s, family: family(act))
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
        FlowScreen {
            TextLink(title: "‹ \(personName)'s plan") { screen = .plan }
            Question(title: "Add something")
            VStack(spacing: 0) {
                ForEach(suggestions, id: \.title) { s in suggestionRow(s) }
                OptionRow(title: "Something else…") { newName = ""; screen = .name }
            }
        }
    }

    @ViewBuilder private func suggestionRow(_ s: PartSuggestions.Suggestion) -> some View {
        let added = PartSuggestions.isAdded(s, parts: parts.map { (kindRaw: $0.kindRaw, label: $0.label) })
        if added {
            suggestionLabel(s.title, trailing: "Added", color: Brand.inkMuted)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(s.title), added")
        } else {
            Button {
                model.addPart(to: moment, kind: s.kind, label: s.label)
                screen = .plan
            } label: {
                suggestionLabel(s.title, trailing: "Add", color: Brand.action)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Add \(s.title)")
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

    var body: some View {
        let progress = PartSteps.progress(step: step, family: family)
        let word = PartSteps.pillWord(for: step)
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
    let household: [Person]
    let personName: String
    let person: Person?
    let back: () -> Void

    @State private var note = ""
    @State private var loaded = false
    @State private var showLifetime = false
    @FocusState private var noteFocused: Bool

    private var family: PartSteps.Family { PartSteps.family(forKindRaw: act.kindRaw) }
    private var current: String { act.currentStep ?? "open" }
    private var ownerIDs: [UUID] { PartOwners.existing(act.ownerIDs, among: household.map(\.id)) }

    var body: some View {
        FlowScreen {
            TextLink(title: "‹ \(personName)'s plan") { saveNote(); back() }
            Text(PartSteps.displayName(kindRaw: act.kindRaw, label: act.label, title: act.title))
                .font(Brand.display(52, relativeTo: .largeTitle)).tracking(-1)
                .foregroundStyle(Brand.ink)
                .lineLimit(3).minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            TextField("Add a note, like what it is or when it arrives.", text: $note, axis: .vertical)
                .lineLimit(1...4)
                .font(Brand.serif(18, relativeTo: .body, italic: true))
                .foregroundStyle(Brand.ink)
                .focused($noteFocused)
                .frame(minHeight: 44, alignment: .topLeading)
                .onChange(of: noteFocused) { _, focused in if !focused { saveNote() } }
            standsList
            shelfList
            ownersList
        } footer: {
            PrimaryButton(title: "Done") { saveNote(); back() }
        }
        .sheet(isPresented: $showLifetime) { LifetimeView() }
        .onAppear {
            guard !loaded else { return }
            note = act.note ?? ""
            loaded = true
        }
    }

    private func saveNote() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != (act.note ?? "") { model.setNote(act, trimmed) }
    }

    private var standsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Where it stands").padding(.bottom, Brand.space2)
            ForEach(PartSteps.steps(for: family), id: \.self) { step in
                let selected = step == current
                Button { if !model.setStep(act, step) { showLifetime = true } } label: {
                    HStack(spacing: Brand.space3) {
                        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 22)).foregroundStyle(selected ? Brand.ink : Brand.inkMuted)
                        Text(PartSteps.word(for: step)).textStyle(selected ? .bodyStrong : .body)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 52)
                    .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(PartSteps.word(for: step))
                .accessibilityValue(selected ? "Selected" : "Not selected")
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                .accessibilityHint("Where it stands. One choice.")
            }
        }
    }

    /// The shelf feeds the gift (roadmap 2.5): saved wishes for this person, one tap to make one the idea.
    @ViewBuilder private var shelfList: some View {
        let wishes = person?.openWishes ?? []
        if family == .buy && (act.kind == .gift || act.kind == .fromSanta || act.kind == .stocking) && !wishes.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "From your saved ideas").padding(.bottom, Brand.space2)
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
            }
        }
    }

    private var ownersList: some View {
        VStack(alignment: .leading, spacing: Brand.space2) {
            Eyebrow(text: "Who it's from")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: Brand.space2)], alignment: .leading,
                      spacing: Brand.space2) {
                chip("You", selected: ownerIDs.isEmpty) { model.setOwners(act, PartOwners.you()) }
                ForEach(household, id: \.id) { p in
                    chip(p.name, selected: ownerIDs.contains(p.id)) {
                        model.setOwners(act, PartOwners.toggled(ownerIDs, tapping: p.id))
                    }
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if selected { Image(systemName: "checkmark").font(.footnote.weight(.bold)) }
                Text(title).font(.callout.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
            }
            .foregroundStyle(selected ? Brand.page : Brand.ink)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
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


/// "Who is Ben to you?" One tap sets the relationship, which shapes suggestions (roadmap 1.6).
struct RelationshipPicker: View {
    @EnvironmentObject var model: AppModel
    let person: Person
    let done: () -> Void

    var body: some View {
        FlowScreen {
            TextLink(title: "‹ \(person.name)'s plan") { done() }
            Question(title: "Who is \(person.name) to you?", subtitle: "It helps Held Dear suggest what families usually plan.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Brand.space2)], alignment: .leading,
                      spacing: Brand.space2) {
                ForEach(Relationship.choices, id: \.self) { word in
                    let selected = person.relationship?.caseInsensitiveCompare(word) == .orderedSame
                    Button {
                        model.setRelationship(person, word)
                        done()
                    } label: {
                        Text(word).font(.callout.weight(.semibold))
                            .foregroundStyle(selected ? Brand.page : Brand.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background {
                                if selected { Capsule().fill(Brand.ink) } else { Capsule().strokeBorder(Brand.inkMuted, lineWidth: 1) }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }
}
