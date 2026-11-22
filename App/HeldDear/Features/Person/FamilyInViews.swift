import Contacts
import SwiftUI

/// "Get the family in" (Graham, Nov 22, 2026). The suggestion on a person's page, the flow that asks the people the
/// user picked (one text each), and the list of who to ask. Every send starts on the who-to-ask screen, where each
/// name is shown and can be unchecked, and the button names everyone it will text: the saved list is never used
/// without that check, so nobody is asked who shouldn't be.
struct FamilyInSuggestion: View {
    @EnvironmentObject var model: AppModel
    let person: Person
    let moment: Moment
    var onOpen: (_ followUp: Bool) -> Void
    @State private var refresh = 0

    var body: some View {
        let days = OccasionDates.daysBetween(Date(), moment.dueDate)
        let record = FamilyCircle.shared.record(for: moment.id)
        let on = model.familyOn(for: moment)
        let followUp = FamilyIn.showsFollowUp(daysLeft: days, cardAskSent: record.choice == .card, followedUp: record.followedUp)
        let subject = moment.type.subject(name: person.name, partner: moment.occasion?.partnerName)
        if followUp || FamilyIn.showsSuggestion(daysLeft: days, on: on, handled: record.handled) {
            Card {
                VStack(alignment: .leading, spacing: Brand.space2) {
                    Text(followUp ? "Remind the family?" : "Get the family in").textStyle(.headline)
                    Text(followUp ? "\(subject.capitalizedFirst) is in \(days) day\(days == 1 ? "" : "s"). One more nudge to the people you asked."
                                  : "\(subject.capitalizedFirst) is in \(days) days. Ask the people you pick to add a note or send a card, one text each.")
                        .textStyle(.callout, color: Brand.inkMuted)
                }
                HStack(spacing: Brand.space4) {
                    Button { onOpen(followUp) } label: {
                        Text("Choose who to ask").textStyle(.bodyStrong, color: Brand.onAction)
                            .padding(.horizontal, Brand.space4).frame(minHeight: 44)
                            .background(Brand.action, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                    }
                    .buttonStyle(PressStyle())
                    TextLink(title: followUp ? "No thanks" : "Not this year") {
                        FamilyCircle.shared.update(moment.id) { r in if followUp { r.followedUp = true } else { r.dismissed = true } }
                        refresh += 1
                        Task { await model.scheduleAlerts() }
                    }
                }
            }
            .id(refresh)
        }
    }
}

extension String {
    /// "josie's birthday" stays as written; only the first letter is raised.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// The flow: what to ask (skipped for the follow-up), who to ask (always), the family page if needed, then one
/// message per person, each sent by the user's own tap in Messages.
struct FamilyInFlow: View {
    @EnvironmentObject var model: AppModel
    let person: Person
    let moment: Moment
    var followUp = false
    var onClose: () -> Void

    private enum Step { case choose, who, page, sending, done }
    @State private var step: Step = .choose
    @State private var choice: FamilyIn.Choice = .card
    @State private var saved: [FamilyIn.Recipient] = []
    @State private var selected: Set<String> = []
    @State private var queue: [FamilyIn.Recipient] = []
    @State private var current: FamilyIn.Recipient?
    @State private var sentTo: [String] = []
    @State private var sharing = false
    // The family page, when gathering notes and none exists yet.
    @State private var fromName = MailAddress.saved?.firstName ?? ""
    @State private var line = ""
    @State private var working = false
    @State private var error: String?

    private var name: String { person.name }
    private var subject: String { moment.type.subject(name: person.name, partner: moment.occasion?.partnerName) }
    private var chosen: [FamilyIn.Recipient] { FamilyIn.textable(saved).filter { selected.contains($0.id) } }

    var body: some View {
        Group {
            switch step {
            case .choose: chooseStep
            case .who: whoStep
            case .page: pageStep
            case .sending: sendingStep
            case .done: doneStep
            }
        }
        .onAppear {
            saved = FamilyCircle.shared.recipients(for: person.id)
            selected = Set(FamilyIn.textable(saved).map(\.id))
            if followUp || !AppFeatures.familyPages { choice = .card; step = .who }
        }
        .sheet(item: $current) { r in
            MessageComposer(recipients: [r.phone ?? ""], body: messageText, image: nil) { result in
                if result == .sent { sentTo.append(r.name) }
                current = nil
                // The next message opens once this sheet has gone.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { sendNext() }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $sharing) {
            ShareSheet(items: [messageText]) { done in
                sharing = false
                if done { sentTo = chosen.map(\.name) }
                finish()
            }
        }
    }

    // MARK: Steps

    private var chooseStep: some View {
        FlowScreen(onClose: onClose) {
            Question(title: "Get the family in on \(subject)?",
                     subtitle: "Pick one. Next you'll check exactly who gets a text.")
            VStack(spacing: 0) {
                OptionRow(title: "Gather notes", caption: "Family adds a note to one page. \(name) sees them all on the day.",
                          action: { choice = .notes; step = .who }, leading: { EmptyView() },
                          trailing: { Image(systemName: "chevron.right").foregroundStyle(Brand.inkMuted) })
                OptionRow(title: "Remind them to send a card", caption: "A text with the date\(model.address(for: person) != nil ? " and \(name)'s address" : "").",
                          action: { choice = .card; step = .who }, leading: { EmptyView() },
                          trailing: { Image(systemName: "chevron.right").foregroundStyle(Brand.inkMuted) })
            }
        }
    }

    private var whoStep: some View {
        FlowScreen(onClose: onClose) {
            Question(title: "Who gets a text?",
                     subtitle: saved.isEmpty ? "Add the people to ask about \(subject). Held Dear keeps the list for next year."
                                             : "Check each name. Only the people checked get a message, one each, and you send every one.")
            RecipientList(person: person, saved: $saved, selected: $selected)
        } footer: {
            PrimaryButton(title: FamilyIn.sendTitle(chosen.map(\.name))) { confirmed() }
                .disabled(chosen.isEmpty)
        }
    }

    private var pageStep: some View {
        FlowScreen(onClose: onClose) {
            Question(title: "Make \(name)'s page",
                     subtitle: "Family adds notes from the link, with no app or account. The page and its notes are deleted 30 days after the day.")
            LineField(label: "Your name, as family knows you", text: $fromName, placeholder: "Your first name", showsDictation: false)
            LineField(label: "A line for family (optional)", text: $line, placeholder: "Write a note for \(name) by \(OccasionDates.shortDate(OccasionDates.adding(days: -1, to: moment.dueDate)))")
            if let error { Text(error).textStyle(.callout, color: Brand.error) }
        } footer: {
            PrimaryButton(title: working ? "Making the page…" : "Make the page") { Task { await makePage() } }
                .disabled(working || fromName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var sendingStep: some View {
        FlowScreen(onClose: onClose) {
            Question(title: "Sending \(sentTo.count + 1) of \(chosen.count)",
                     subtitle: "Tap Send in each message. Cancel skips that person.")
        }
    }

    private var doneStep: some View {
        FlowScreen(onClose: onClose) {
            Question(title: sentTo.isEmpty ? "Nothing sent" : "Asked \(FamilyIn.sendTitle(sentTo).dropFirst(5))",
                     subtitle: sentTo.isEmpty ? "You can come back to this from \(name)'s page."
                                              : (choice == .notes ? "Their notes collect on \(name)'s page. On the day, send it from \(name)'s details."
                                                                  : "Held Dear offers one reminder three days before."))
        } footer: {
            PrimaryButton(title: "Done", action: onClose)
        }
    }

    // MARK: Sending

    private var messageText: String {
        if followUp { return FamilyIn.followUpText(subject: subject.capitalizedFirst, date: moment.dueDate) }
        switch choice {
        case .notes: return FamilyIn.notesText(subject: subject, name: name, date: moment.dueDate, link: moment.familyInviteURL ?? "")
        case .card: return FamilyIn.cardText(subject: subject.capitalizedFirst, name: name, date: moment.dueDate, address: model.address(for: person))
        }
    }

    private func confirmed() {
        if choice == .notes && moment.familyInviteURL == nil { step = .page; return }
        startSending()
    }

    private func startSending() {
        sentTo = []
        guard MessageComposer.canSend else { sharing = true; return }
        queue = chosen
        step = .sending
        sendNext()
    }

    private func sendNext() {
        guard !queue.isEmpty else { finish(); return }
        current = queue.removeFirst()
    }

    private func finish() {
        if !sentTo.isEmpty {
            FamilyCircle.shared.update(moment.id) { r in
                if followUp { r.followedUp = true } else { r.choice = choice }
            }
            Task { await model.scheduleAlerts() }
        }
        step = .done
    }

    private func makePage() async {
        working = true
        defer { working = false }
        do {
            let c = try await FamilyPages.create(firstName: person.name, occasion: moment.type, date: moment.dueDate,
                                                 fromName: fromName.trimmingCharacters(in: .whitespaces),
                                                 message: line.trimmingCharacters(in: .whitespacesAndNewlines),
                                                 photo: PhotoStore.load(person.photoFiles.last))
            moment.familyPageID = c.id
            moment.familyOwnerKey = c.ownerKey
            moment.familyInviteURL = c.inviteURL
            moment.familyGiftURL = c.giftURL
            model.save()
            startSending()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// The people to ask for one person: checkmarks when sending, swipe to take someone off the list, Add from Contacts.
/// Saved on this phone only.
struct RecipientList: View {
    let person: Person
    @Binding var saved: [FamilyIn.Recipient]
    @Binding var selected: Set<String>
    /// False on the details page, where the list is only kept, not sent to: no checkmarks.
    var picking = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(saved) { r in
                let canText = !(r.phone ?? "").isEmpty
                Button {
                    guard picking, canText else { return }
                    if selected.contains(r.id) { selected.remove(r.id) } else { selected.insert(r.id) }
                } label: {
                    HStack(spacing: Brand.space3) {
                        if picking {
                            Image(systemName: selected.contains(r.id) && canText ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22)).foregroundStyle(canText ? Brand.action : Brand.line)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).textStyle(.body)
                            Text(canText ? (r.phone ?? "") : "No number on the contact").textStyle(.caption, color: Brand.inkMuted)
                        }
                        Spacer()
                    }
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
                .swipeToRemove("Take off") { remove(r) }
                .accessibilityAddTraits(picking && selected.contains(r.id) ? .isSelected : [])
                .accessibilityAction(named: "Take \(r.name) off the list") { remove(r) }
            }
            TextLink(title: "+ Add from Contacts") { add() }
                .padding(.leading, -8)
                .padding(.top, Brand.space2)
            if !saved.isEmpty {
                Text("Swipe a name to take it off the list for \(person.name).").textStyle(.caption, color: Brand.inkMuted)
            }
        }
    }

    private func remove(_ r: FamilyIn.Recipient) {
        saved.removeAll { $0.id == r.id }
        selected.remove(r.id)
        FamilyCircle.shared.setRecipients(saved, for: person.id)
    }

    private func add() {
        MultiContactPickerPresenter.shared.present { contacts in
            let people = contacts.filter { $0.identifier != person.contactID }.map(Self.recipient)
            FamilyCircle.shared.add(people, for: person.id)
            saved = FamilyCircle.shared.recipients(for: person.id)
            // Newly added people are checked; everyone else keeps the choice already made.
            for p in people where !(p.phone ?? "").isEmpty { selected.insert(p.id) }
        }
    }

    static func recipient(_ c: CNContact) -> FamilyIn.Recipient {
        let given = c.isKeyAvailable(CNContactGivenNameKey) ? c.givenName : ""
        let family = c.isKeyAvailable(CNContactFamilyNameKey) ? c.familyName : ""
        let nick = c.isKeyAvailable(CNContactNicknameKey) ? c.nickname : ""
        let full = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
        var phone: String?
        if c.isKeyAvailable(CNContactPhoneNumbersKey) {
            let mobile = c.phoneNumbers.first { $0.label == CNLabelPhoneNumberMobile || $0.label == CNLabelPhoneNumberiPhone }
            phone = (mobile ?? c.phoneNumbers.first)?.value.stringValue
        }
        return FamilyIn.Recipient(id: c.identifier, name: !nick.isEmpty ? nick : (full.isEmpty ? "Someone" : full), phone: phone)
    }
}

/// The details page's list: who to ask for this person, kept for every year.
struct FamilyRecipientsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person
    @State private var saved: [FamilyIn.Recipient] = []
    @State private var none: Set<String> = []

    var body: some View {
        FlowScreen(onClose: { dismiss() }) {
            Question(title: "Who to ask for \(person.name)",
                     subtitle: "When a day comes, Held Dear shows this list and you check each name before any text goes out.")
            RecipientList(person: person, saved: $saved, selected: $none, picking: false)
        }
        .onAppear { saved = FamilyCircle.shared.recipients(for: person.id) }
    }
}
