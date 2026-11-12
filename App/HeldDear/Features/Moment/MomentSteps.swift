import MessageUI
import PhotosUI
import SwiftUI
import UIKit

// MARK: C3. The next step only

struct NextStepView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openURL) private var openURL
    let moment: Moment
    var go: (MomentStep) -> Void
    var close: () -> Void
    @State private var dinnerDate: Date = Date()
    @State private var askingAddress = false
    @State private var photoItem: PhotosPickerItem?
    @State private var calendarFailed = false

    private var name: String { moment.person?.name ?? "" }
    private var cutoff: Date { OccasionDates.adding(days: -OccasionDates.cutoffDays, to: moment.dueDate) }
    private var cutoffPassed: Bool { OccasionDates.daysBetween(Date(), cutoff) < 0 }

    var body: some View {
        Group {
            if let plan = moment.plan {
                if plan.isDone { doneView(plan) } else { planView(plan) }
            } else {
                Color.clear.onAppear { go(.choose) }
            }
        }
        .sheet(isPresented: $askingAddress) { addressRequest }
        .onAppear {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: moment.dueDate)
            comps.hour = 18
            dinnerDate = Calendar.current.date(from: comps) ?? moment.dueDate
        }
        .onChange(of: photoItem) { _, item in savePhoto(item) }
        .alert("Held Dear couldn't add it to your calendar", isPresented: $calendarFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Calendar access may be off for Held Dear in Settings.")
        }
    }

    @ViewBuilder private func planView(_ plan: Act) -> some View {
        switch plan.kind {
        case .gift: giftView(plan)
        case .card: cardView
        case .dinner: dinnerView
        case .call, .message: morningOfView(plan)
        case .other: otherView(plan)
        }
    }

    private var wish: Wish? {
        guard let id = moment.plan?.wishID else { return nil }
        return moment.person?.wishes.first { $0.id == id }
    }

    // Gift, with or without a saved link.
    private func giftView(_ plan: Act) -> some View {
        let title = plan.title ?? "A gift"
        let link = wish?.url.flatMap(URL.init(string:))
        return FlowScreen(onClose: close) {
            Question(tag: "Plan · \(title)",
                     title: cutoffPassed ? "Order soon" : "Order by \(OccasionDates.longDate(cutoff))",
                     subtitle: "That leaves time for shipping before \(OccasionDates.longDate(moment.dueDate)).")
            Card {
                HStack(spacing: 14) {
                    PhotoTile(image: PhotoStore.load(wish?.imageFile), label: "Gift", height: 72, radius: Brand.radiusMd)
                        .frame(width: 72)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).textStyle(.bodyStrong)
                        if let wish {
                            Text([wish.host, "saved in \(wish.capturedAt.formatted(.dateTime.month(.wide)))"].compactMap { $0 }.joined(separator: " · "))
                                .textStyle(.caption, color: Brand.inkMuted)
                        }
                    }
                }
                if let link { PrimaryButton(title: "Open the link") { openURL(link) } }
            }
            photoPrompt
        } footer: {
            SecondaryButton(title: link == nil ? "Done, it's bought" : "Done, it's ordered") { finish() }
            TextLink(title: "Change plan") { go(.choose) }
        }
    }

    private var cardView: some View {
        let address = model.address(for: moment.person)
        return FlowScreen(onClose: close) {
            if let address {
                Question(tag: "Plan · A card",
                         title: cutoffPassed ? "Mail it soon" : "Mail by \(OccasionDates.longDate(cutoff))",
                         subtitle: "It arrives before \(OccasionDates.longDate(moment.dueDate)).")
                Card {
                    Eyebrow(text: "\(name)'s address")
                    Text(address).textStyle(.body).textSelection(.enabled)
                }
            } else {
                Question(tag: "Plan · A card", title: "No address for \(name)",
                         subtitle: "Ask once, and it's here every year after. It comes from your contacts.")
            }
            photoPrompt
        } footer: {
            if address == nil {
                PrimaryButton(title: "Ask \(name) for it") { askingAddress = true }
                TextLink(title: "Change plan") { go(.choose) }
            } else {
                SecondaryButton(title: "Done, it's mailed") { finish() }
                TextLink(title: "Change plan") { go(.choose) }
            }
        }
    }

    private var dinnerView: some View {
        FlowScreen(onClose: close) {
            Question(tag: "Plan · Dinner together", title: "Hold a date for dinner",
                     subtitle: "Held Dear adds it to your calendar.")
            Card {
                DatePicker("Dinner", selection: $dinnerDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Brand.action)
            }
            photoPrompt
        } footer: {
            PrimaryButton(title: "Add to calendar") {
                Task {
                    let ok = await CalendarService.addDinner(title: "Dinner with \(name)", on: dinnerDate)
                    if ok {
                        moment.plan?.dinnerDate = dinnerDate
                        model.completePlan(moment, how: .calendar)
                        close()
                    } else {
                        calendarFailed = true
                    }
                }
            }
            TextLink(title: "Change plan") { go(.choose) }
        }
    }

    private func morningOfView(_ plan: Act) -> some View {
        let verb = plan.kind == .call ? "calls" : "opens a message to"
        return FlowScreen(onClose: close) {
            Spacer(minLength: 40)
            Question(tag: plan.kind == .call ? "Plan · A call" : "Plan · A message",
                     title: "We'll set it up on the morning of",
                     subtitle: "On \(OccasionDates.longDate(moment.dueDate)) at 9:00, one tap \(verb) \(name).")
            photoPrompt
        } footer: {
            PrimaryButton(title: "OK", action: close)
            TextLink(title: "Change plan") { go(.choose) }
        }
    }

    private func otherView(_ plan: Act) -> some View {
        FlowScreen(onClose: close) {
            Spacer(minLength: 40)
            Question(tag: "Plan", title: plan.title ?? "Something special",
                     subtitle: "Tap Done when it's taken care of. Held Dear checks in before \(OccasionDates.longDate(moment.dueDate)).")
            photoPrompt
        } footer: {
            SecondaryButton(title: "Done") { finish() }
            TextLink(title: "Change plan") { go(.choose) }
        }
    }

    private func doneView(_ plan: Act) -> some View {
        FlowScreen(onClose: close) {
            Spacer(minLength: 40)
            Question(tag: "Done", title: "It's all set",
                     subtitle: OccasionDates.daysBetween(Date(), moment.dueDate) > 0
                        ? "On \(OccasionDates.longDate(moment.dueDate)), a message for \(name) is ready to send."
                        : "This year is in \(name)'s record.")
            if let p = moment.person, let entry = p.ledger.first(where: { $0.momentID == moment.id }) {
                ContextLine(text: entry.line ?? entry.what)
            }
        } footer: {
            PrimaryButton(title: "OK", action: close)
        }
    }

    /// Inner ring, no photos of this person yet: once, "Add a photo of you two".
    @ViewBuilder private var photoPrompt: some View {
        if let p = moment.person, p.ring == .inner, p.photoFiles.isEmpty, !moment.photoPromptShown {
            HStack(spacing: 14) {
                Image(systemName: "plus").font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.ink)
                    .frame(width: 56, height: 56)
                    .background(Brand.faceFills[0], in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a photo of you two").font(TypeStyle.callout.font.weight(.heavy)).foregroundStyle(Brand.ink)
                    Text("For the message on the day").textStyle(.caption, color: Brand.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text("Add").font(TypeStyle.callout.font.weight(.bold)).foregroundStyle(Brand.action).frame(minWidth: 44, minHeight: 44)
                }
                Button {
                    moment.photoPromptShown = true
                    model.save()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Brand.inkMuted).frame(width: 32, height: 44)
                }
                .accessibilityLabel("Skip")
            }
            .padding(Brand.space4)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
        }
    }

    private func savePhoto(_ item: PhotosPickerItem?) {
        guard let item, let person = moment.person else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let file = PhotoStore.save(data: data) {
                person.photoFiles.append(file)
                moment.photoPromptShown = true
                model.save()
            }
        }
    }

    @ViewBuilder private var addressRequest: some View {
        let phone = model.phone(for: moment.person)
        let text = "Hi \(name), what's your mailing address these days? I want to send you something."
        if let phone, MessageComposer.canSend {
            MessageComposer(recipients: [phone], body: text, image: nil) { _ in askingAddress = false }
                .ignoresSafeArea()
        } else {
            ShareSheet(items: [text]) { _ in askingAddress = false }
        }
    }

    private func finish() {
        model.completePlan(moment)
        close()
    }
}

// MARK: D2. Pick a photo, send the message

struct PhotoStep: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    var go: (MomentStep) -> Void
    var close: () -> Void
    @State private var choices: [PhotoChoice] = []
    @State private var selected: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var composing = false
    @State private var sharing = false
    @State private var failed = false
    @State private var confirmShared = false

    private var name: String { moment.person?.name ?? "" }
    private var selectedChoice: PhotoChoice? { choices.first { $0.id == selected } }

    var body: some View {
        Group {
            if confirmShared { sharedConfirm } else { picker }
        }
        .onAppear(perform: load)
        .onChange(of: pickerItem) { _, item in addPicked(item) }
        .fullScreenCover(isPresented: $composing) { composer.ignoresSafeArea() }
        .sheet(isPresented: $sharing) {
            ShareSheet(items: shareItems) { completed in
                sharing = false
                if completed { confirmShared = true }
            }
        }
    }

    private var picker: some View {
        FlowScreen(onClose: close) {
            Question(title: choices.isEmpty ? "Send \(name) a message" : "Pick a photo for \(name)",
                     subtitle: "Your message opens next. Add your own words or send it as is.", style: .title)
            if failed {
                Text("That didn't go through.").textStyle(.bodyStrong, color: Brand.error)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(choices) { choice in
                    let on = choice.id == selected
                    Button { selected = choice.id } label: {
                        ZStack(alignment: .bottomTrailing) {
                            PhotoTile(image: choice.image, label: choice.label)
                            if on { CheckBadge(size: 26).padding(10) }
                        }
                        .padding(on ? 3 : 0)
                        .overlay(RoundedRectangle(cornerRadius: Brand.radiusMd + 3, style: .continuous)
                            .stroke(on ? Brand.action : Color.clear, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.label)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(choices.isEmpty ? "Add a photo" : "Choose another")
                        .font(TypeStyle.callout.font.weight(.heavy)).foregroundStyle(Brand.action)
                        .frame(maxWidth: .infinity).frame(height: 150)
                        .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                }
            }
        } footer: {
            PrimaryButton(title: failed ? "Try again" : (selectedChoice == nil ? "Write the message" : "Use this photo")) { send() }
        }
    }

    private var sharedConfirm: some View {
        FlowScreen(onClose: close) {
            Spacer(minLength: 80)
            Question(title: "Did it reach \(name)?")
        } footer: {
            PrimaryButton(title: "Yes") { complete() }
            TextLink(title: "Not yet") { confirmShared = false }
        }
    }

    private var greetingText: String { "Happy birthday, \(name)!" }

    private var shareItems: [Any] {
        var items: [Any] = [greetingText]
        if let image = selectedChoice?.image { items.append(image) }
        return items
    }

    @ViewBuilder private var composer: some View {
        MessageComposer(recipients: [model.phone(for: moment.person)].compactMap { $0 }, body: greetingText,
                        image: selectedChoice?.image) { result in
            composing = false
            switch result {
            case .sent: complete(how: .messageSent)
            case .failed: failed = true
            default: failed = false   // Cancelled: back on D2, the Moment stays open.
            }
        }
    }

    private func send() {
        failed = false
        if MessageComposer.canSend { composing = true } else { sharing = true }
    }

    private func complete(how: ConfirmedBy = .user) {
        var file = selectedChoice?.file
        if file == nil, let image = selectedChoice?.image { file = PhotoStore.save(image) }
        model.completeGreeting(moment, kind: .message, how: how, photoFile: file)
        go(.record)
    }

    private func load() {
        guard let p = moment.person else { return }
        choices = model.photoChoices(for: p)
        selected = choices.first?.id
    }

    /// A photo from the system picker joins this person's set, so the set improves every year.
    private func addPicked(_ item: PhotosPickerItem?) {
        guard let item, let person = moment.person else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self), let file = PhotoStore.save(data: data),
                  let image = PhotoStore.load(file) else { return }
            person.photoFiles.append(file)
            model.save()
            let choice = PhotoChoice(id: "picked-\(file)", image: image, file: file, label: "Photo you picked")
            choices.insert(choice, at: 0)
            if choices.count > 4 { choices.removeLast() }
            selected = choice.id
        }
    }
}

// MARK: E1. Record the year

struct RecordStep: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    var close: () -> Void
    @State private var line = ""

    var body: some View {
        let name = moment.person?.name ?? ""
        let photo = PhotoStore.load(moment.acts.compactMap(\.photoFile).first)
        FlowScreen(onClose: close) {
            Question(tag: "Done", title: "One line for this year?", subtitle: "It goes in \(name)'s yearly record.")
            Card {
                Eyebrow(text: eyebrow)
                if let photo { PhotoTile(image: photo, label: "Photo") }
                Text(MomentEngine.whatWasDone(moment)).textStyle(.bodyStrong)
            }
            LineField(label: "Your line (optional)", text: $line, placeholder: "She called back crying happy tears", onSubmit: save)
        } footer: {
            PrimaryButton(title: "Save", action: save)
            TextLink(title: "Skip") {
                model.record(moment, line: nil)
                close()
            }
        }
    }

    private var eyebrow: String {
        var text = "\(moment.year) · \(moment.occasion?.type.label ?? "Birthday")"
        if let t = moment.turning { text += " · turning \(t)" }
        return text
    }

    private func save() {
        model.record(moment, line: line)
        close()
    }
}
