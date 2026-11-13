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

    /// C2 in the Horizon look: one big question, the thing they mentioned as the one filled tile,
    /// everything else as stone tiles in a grid. One decision.
    private var choices: some View {
        let wishes = Array(moment.person?.openWishes.prefix(3) ?? [])
        let days = OccasionDates.daysBetween(Date(), moment.dueDate)
        let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return FlowScreen(onClose: { model.route = nil }) {
            VStack(alignment: .leading, spacing: Brand.space2) {
                Text("\(name) · \(OccasionDates.shortDate(moment.dueDate)) · \(OccasionDates.countdown(to: moment.dueDate, from: Date()))")
                    .textStyle(.eyebrow)
                Text("What will you do for \(name)?").font(Brand.display(40)).tracking(-0.8)
                    .foregroundStyle(Brand.ink).fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let last = model.lastYear(for: moment) {
                    Text("Last year: \(last.what.prefix(1).lowercased() + last.what.dropFirst())")
                        .font(Brand.serif(18, relativeTo: .callout, italic: true)).foregroundStyle(Brand.inkSoft)
                }
            }
            if let first = wishes.first {
                PlanTile(eyebrow: "\(name) mentioned", title: first.text,
                         caption: days > OccasionDates.cutoffDays
                            ? "Order by \(OccasionDates.shortDate(OccasionDates.adding(days: -OccasionDates.cutoffDays, to: moment.dueDate)))"
                            : first.savedLine,
                         filled: true, tall: true) { pick(.gift, wish: first) }
            }
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(wishes.dropFirst(), id: \.id) { wish in
                    PlanTile(title: wish.text, caption: "Saved idea") { pick(.gift, wish: wish) }
                }
                if days >= 6 {
                    PlanTile(title: "Mail a real card", caption: "Pen-written, mailed for you · $6.99", filled: wishes.isEmpty) { go(.mailCard) }
                }
                PlanTile(title: "Find a gift", caption: "Ideas for \(name), and your shelf") { model.route = .ideas(moment.id) }
                PlanTile(title: "Call \(name)", caption: "A reminder that morning") { pick(.call) }
                PlanTile(title: "Dinner together", caption: "On your calendar") { pick(.dinner) }
                PlanTile(title: "Something else", caption: "Say it in one line") { describing = true }
            }
        }
    }

    private var somethingElse: some View {
        FlowScreen(onClose: { describing = false }) {
            Question(title: "What will you do for \(name)?")
            LineField(label: "One line to describe it", text: $otherText, placeholder: "A trip to the garden show", onSubmit: saveOther)
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
            Question(title: "It's \(moment.subject).", subtitle: moment.countLine.map { "\($0) today." })
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
            Question(title: days <= 1 ? "\(moment.subject.capitalizedFirst) was yesterday." : "\(moment.subject.capitalizedFirst) was \(days) days ago.",
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

/// One option on the plan screen. Filled (oxblood) for the single suggested option, stone for the rest.
struct PlanTile: View {
    var eyebrow: String? = nil
    var title: String
    var caption: String?
    var filled = false
    var tall = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                if let eyebrow {
                    Text(eyebrow).textStyle(.eyebrow, color: filled ? Brand.onAction.opacity(0.85) : Brand.inkMuted)
                }
                Spacer(minLength: 0)
                Text(title)
                    .font(tall ? Brand.display(30, relativeTo: .title2) : Brand.serif(20, relativeTo: .headline))
                    .foregroundStyle(filled ? Brand.onAction : Brand.ink)
                    .multilineTextAlignment(.leading).lineLimit(3)
                if let caption {
                    Text(caption).font(.footnote.weight(.medium))
                        .foregroundStyle(filled ? Brand.onAction.opacity(0.9) : Brand.inkMuted)
                        .multilineTextAlignment(.leading).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: tall ? 150 : 118, alignment: .topLeading)
            .padding(Brand.space4)
            .background(filled ? Brand.action : Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}
