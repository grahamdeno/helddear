import SwiftUI

/// One Moment's journey, one decision per screen. Steps fade into each other (no slides, per Reduce Motion guidance).
struct MomentFlowView: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    @State private var step: MomentStep

    init(moment: Moment, start: MomentStep) {
        self.moment = moment
        _step = State(initialValue: start == .auto ? Self.autoStep(for: moment) : start)
    }

    static func autoStep(for m: Moment, now: Date = Date()) -> MomentStep {
        let days = OccasionDates.daysBetween(now, m.dueDate)
        switch m.status {
        case .missed: return .missed
        case .lateSent: return m.person?.ledger.contains { $0.momentID == m.id } == true ? .nextStep : .record
        case .done:
            if days == 0 && !m.greetingSent {
                return .photo
            }
            return m.person?.ledger.contains { $0.momentID == m.id } == true || days > 0 ? .nextStep : .record
        case .planning: return days == 0 ? .dayOf : .nextStep
        default: return days == 0 ? .dayOf : .choose
        }
    }

    var body: some View {
        ZStack {
            switch step {
            case .auto, .choose: ChooseStep(moment: moment, go: go)
            case .wishPrompt: WishPromptStep(moment: moment, close: close)
            case .nextStep: NextStepView(moment: moment, go: go, close: close)
            case .mailCard: MailCardFlow(moment: moment, go: go, close: close)
            case .dayOf: DayOfStep(moment: moment, go: go, close: close)
            case .photo: PhotoStep(moment: moment, go: go, close: close)
            case .confirmCall: ConfirmCallStep(moment: moment, go: go, close: close)
            case .record: RecordStep(moment: moment, close: close)
            case .missed: MissedStep(moment: moment, go: go, close: close)
            }
        }
        .id(stepKey)
        .transition(.opacity)
        .animation(.easeOut(duration: 0.22), value: stepKey)
        .background(Brand.page.ignoresSafeArea())
    }

    private var stepKey: String { String(describing: step) }

    private func go(_ next: MomentStep) {
        withAnimation(.easeOut(duration: 0.22)) { step = next }
    }

    private func close() { model.route = nil }
}

// MARK: B3. Wish prompt

struct WishPromptStep: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    var close: () -> Void
    @State private var text = ""

    var body: some View {
        let name = moment.person?.name ?? ""
        FlowScreen(onClose: close) {
            Question(tag: "\(name) · \(OccasionDates.countdown(to: moment.dueDate, from: Date()))",
                     title: "Has \(name) mentioned wanting anything lately?")
            LineField(label: "One line is plenty", text: $text, onSubmit: save)
            Text("Example: the blue gardening gloves from the garden center")
                .textStyle(.caption, color: Brand.inkMuted).padding(.top, -12)
        } footer: {
            PrimaryButton(title: "Save", action: save)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            TextLink(title: "Nothing yet", action: close)
        }
    }

    private func save() {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, let person = moment.person else { return }
        model.addWish(to: person, text: t)
        close()
    }
}

// MARK: C2. Choose what to do

struct ChooseStep: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    var go: (MomentStep) -> Void
    @State private var describing = false
    @State private var otherText = ""

    var body: some View {
        if describing { somethingElse } else { choices }
    }

    private var name: String { moment.person?.name ?? "" }

    private var choices: some View {
        let wishes = Array(moment.person?.openWishes.prefix(3) ?? [])
        var sub = OccasionDates.longDate(moment.dueDate)
        if let t = moment.turning { sub += " · turning \(t)" }
        return FlowScreen(onClose: { model.route = nil }) {
            Question(tag: "\(moment.occasion?.type.label ?? "Birthday") · \(OccasionDates.countdown(to: moment.dueDate, from: Date()))",
                     title: "What will you do for \(name)?", subtitle: sub)
            if let last = model.lastYear(for: moment) {
                ContextLine(text: "Last year: \(last.what.prefix(1).lowercased() + last.what.dropFirst())")
            }
            if !wishes.isEmpty {
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Eyebrow(text: "Saved ideas")
                    ForEach(wishes, id: \.id) { wish in
                        OptionRow(title: wish.text, caption: wish.savedLine) { pick(.gift, wish: wish) }
                    }
                }
            }
            if OccasionDates.daysBetween(Date(), moment.dueDate) >= 6 {
                OptionRow(title: "Mail a real card",
                          caption: "Written in pen, stamped and mailed for you · $6.99",
                          action: { go(.mailCard) },
                          leading: {
                              Image(systemName: "envelope.fill").font(.system(size: 18, weight: .semibold))
                                  .foregroundStyle(Brand.action).frame(width: 32)
                          },
                          trailing: { ChevronDisc() })
            }
            VStack(alignment: .leading, spacing: Brand.space2) {
                Eyebrow(text: wishes.isEmpty ? "Pick one" : "Or")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    SecondaryButton(title: "Send a card") { pick(.card) }
                    SecondaryButton(title: "Call \(name)") { pick(.call) }
                    SecondaryButton(title: "Dinner together") { pick(.dinner) }
                    SecondaryButton(title: "Something else") { describing = true }
                }
            }
        }
    }

    private var somethingElse: some View {
        FlowScreen(onClose: { describing = false }) {
            Question(title: "What will you do for \(name)?")
            LineField(label: "One line to describe it", text: $otherText, placeholder: "Take her to the garden show", onSubmit: saveOther)
        } footer: {
            PrimaryButton(title: "Save", action: saveOther)
                .disabled(otherText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func saveOther() {
        let t = otherText.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        pick(.other, title: t)
    }

    private func pick(_ kind: ActKind, wish: Wish? = nil, title: String? = nil) {
        model.choosePlan(moment, kind: kind, title: title, wish: wish)
        go(.nextStep)
    }
}

// MARK: D1 in the app

struct DayOfStep: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    var go: (MomentStep) -> Void
    var close: () -> Void

    var body: some View {
        let name = moment.person?.name ?? ""
        let callPlan = moment.plan?.kind == .call && moment.plan?.isDone != true
        let hasPhone = model.phone(for: moment.person) != nil
        FlowScreen(onClose: close) {
            if let p = moment.person { Face(person: p, size: 88).frame(maxWidth: .infinity).padding(.top, 80) }
            Question(title: "It's \(name)'s birthday.", subtitle: moment.turning.map { "Turning \($0) today." })
        } footer: {
            if !hasPhone, let p = moment.person {
                PrimaryButton(title: "Add \(name)'s number") { model.route = .person(p.id) }
            } else if callPlan {
                PrimaryButton(title: "Call \(name)") { if !model.startCall(moment) { go(.photo) } }
                TextLink(title: "Send a message instead") { go(.photo) }
            } else {
                PrimaryButton(title: "Send \(name) a message") { go(.photo) }
                TextLink(title: "Call instead") { _ = model.startCall(moment) }
            }
        }
    }
}

// MARK: E1 first question, when a call can't be confirmed

struct ConfirmCallStep: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    var go: (MomentStep) -> Void
    var close: () -> Void

    var body: some View {
        let name = moment.person?.name ?? ""
        FlowScreen(onClose: close) {
            if let p = moment.person { Face(person: p, size: 88).frame(maxWidth: .infinity).padding(.top, 80) }
            Question(title: "Did you reach \(name)?")
        } footer: {
            PrimaryButton(title: "Yes") {
                model.completeGreeting(moment, kind: .call, how: .callConfirmed)
                go(.record)
            }
            TextLink(title: "Not yet") {
                NotificationService.shared.scheduleEveningCheck(momentID: moment.id, name: name)
                close()
            }
        }
    }
}

// MARK: F1. Missed

struct MissedStep: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    var go: (MomentStep) -> Void
    var close: () -> Void

    var body: some View {
        let name = moment.person?.name ?? ""
        let days = OccasionDates.daysBetween(moment.dueDate, Date())
        FlowScreen(onClose: close) {
            if let p = moment.person { Face(person: p, size: 88).frame(maxWidth: .infinity).padding(.top, 120) }
            Question(title: days <= 1 ? "\(name)'s birthday was yesterday." : "\(name)'s birthday was \(days) days ago.",
                     subtitle: "A late note still counts.")
        } footer: {
            PrimaryButton(title: "Send a late note") { go(.photo) }
            TextLink(title: "Let it go") {
                model.letGo(moment)
                close()
            }
        }
    }
}
