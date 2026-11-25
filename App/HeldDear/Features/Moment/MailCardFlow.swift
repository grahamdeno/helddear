import PassKit
import SwiftUI
import UIKit

/// "Mail a real card": Handwrytten writes the message in pen and mails it with the user's return address.
/// Pick a card, write the message, check the addresses, pay with Apple Pay. One decision per screen.
/// What a mailed card is for: a day, or a reason (story 2.8).
struct MailContext {
    let person: Person?
    let occasionKey: String
    let opening: String
    let greeting: String
    let onMailed: (MailedCardRecord) -> Void

    static func occasionKey(for type: OccasionType) -> String { type.rawValue }
}

/// What a paid, placed card leaves on the phone for the person's year: the card, its message, and a picture of its
/// front, kept with the record (Graham, Nov 25, 2026).
struct MailedCardRecord {
    let cardName: String
    let message: String
    let cover: UIImage?
}

struct MailCardFlow: View {
    @EnvironmentObject var model: AppModel
    let context: MailContext
    /// Back to the day's other choices, when the flow was opened from them; otherwise "Choose something else" closes.
    var go: ((MomentStep) -> Void)? = nil
    var close: () -> Void

    enum Step: Equatable { case intro, loading, pick, message, recipient, sender, review, done(String), failed(String) }
    /// The first mailed card starts with how it works (Nov 21, 2026); after that, straight to the cards.
    @State private var step: Step = UserDefaults.standard.bool(forKey: "mailedCardIntroSeen") ? .loading : .intro
    @State private var catalog: MailedCards.Catalog?
    @State private var card: MailCard?
    @State private var section: String?
    @State private var searchText = ""
    @State private var message = ""
    @State private var wishes = ""
    @State private var recipient = MailAddress()
    /// The address came from Contacts, so there's nothing to keep (story 2.13: Contacts stay read only, never copied).
    @State private var fromContacts = false
    /// The address was already kept for this person, so there's nothing to ask: edits are kept too (Graham, Nov 25, 2026).
    @State private var savedOnPerson = false
    @State private var keepAddress = true
    @State private var sender = MailAddress.saved ?? MailAddress()
    /// A complete saved return address skips its step; the review screen has a link to change it (Graham, Nov 25, 2026).
    private let hadReturnAddress = MailAddress.saved?.isComplete == true
    /// The card opened full screen.
    @State private var viewing: MailCard?
    /// The picked card's front as the review screen drew it, kept with the year's record after the order.
    @State private var cover: UIImage?
    @State private var paying = false
    /// The order number for the done screen, so the person has it if they need help (design review, Nov 25, 2026).
    @State private var orderNumber: String?
    @State private var checkout = ApplePayCheckout()
    @State private var reference = UUID().uuidString

    private var name: String { DisplayName.plain(context.person?.name ?? "") }
    private var price: String {
        let cents = catalog?.priceCents ?? 799
        return (Double(cents) / 100).formatted(.currency(code: "USD"))
    }

    var body: some View {
        ZStack {
            switch step {
            case .intro: intro
            case .loading: loading
            case .pick: pick
            case .message: messageStep
            case .recipient: addressStep(title: "Where does it go?", subtitle: "\(name)'s mailing address.", address: $recipient,
                                         next: hadReturnAddress ? .review : .sender, isRecipient: true)
            case .sender: addressStep(title: "Your return address", subtitle: "It goes on the envelope. Kept for next time.", address: $sender, next: .review, isRecipient: false)
            case .review: review
            case .done(let mailing): done(mailing)
            case .failed(let why): failed(why)
            }
        }
        .animation(Motion.animation(.easeOut(duration: 0.22)), value: step)
        .task { await load() }
        .fullScreenCover(item: $viewing) { c in CardViewer(card: c) { card = c } }
        // A new card means a new picture for the year; never keep the last card's.
        .onChange(of: card) { _, _ in cover = nil }
    }

    // MARK: Steps

    private var loading: some View {
        FlowScreen(onClose: close) {
            Spacer(minLength: 120)
            ProgressView().frame(maxWidth: .infinity)
            Text("Finding cards…").textStyle(.callout, color: Brand.inkMuted).frame(maxWidth: .infinity)
        }
    }

    /// How a mailed card works, with an example (Nov 21, 2026).
    private var intro: some View {
        FlowScreen(onClose: close) {
            Question(tag: "Mailed for you · \(price)", title: "A real card, in the mail",
                     subtitle: "You choose a paper card and write the words. It arrives at \(name.isEmpty ? "the" : name + "'s") door looking handwritten, because it is: written in pen.", style: .title)
            HandwrittenSample(message: sampleMessage, signature: wishes.isEmpty ? "Love, you" : wishes)
                .padding(.vertical, Brand.space2)
            VStack(alignment: .leading, spacing: Brand.space3) {
                introStep(1, "Pick a card", "Real folded cards from Handwrytten, the company that writes and mails them.")
                introStep(2, "Write your message", "Your words, as long as the card allows.")
                introStep(3, "It's written in real pen", "A writing machine holds a ballpoint pen and writes your message and the envelope in a handwriting style.")
                introStep(4, "Stamped and mailed", "First-class mail, with your return address on the envelope.")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(MailArrival.arrivalLine(orderedOn: Date())).textStyle(.bodyStrong)
                if let line = MailArrival.christmasLine(today: Date(), orderBy: MailArrival.day(fromISO: catalog?.christmasOrderBy)) {
                    Text(line).textStyle(.callout, color: Brand.action)
                }
            }
            .accessibilityElement(children: .combine)
            Text("Pay with Apple Pay. Held Dear sends only the card, your message and the two addresses, to mail it.")
                .textStyle(.caption, color: Brand.inkMuted)
            Link("Terms of sale and refunds", destination: URL(string: "https://helddear.tangomike.app/terms")!)
                .font(.callout).foregroundStyle(Brand.action).frame(minHeight: 44)
        } footer: {
            PrimaryButton(title: "Choose a card") {
                UserDefaults.standard.set(true, forKey: "mailedCardIntroSeen")
                if let catalog { step = catalog.cards.isEmpty ? .failed("No cards for this occasion are available right now.") : .pick }
                else { step = .loading; Task { await load() } }
            }
        }
    }

    private var sampleMessage: String {
        let text = message.isEmpty ? context.greeting : message
        return text.isEmpty ? "Happy birthday! Thinking of you today and hoping it's a wonderful one." : text
    }

    private func introStep(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Brand.space3) {
            Text("\(n)").font(Brand.display(22)).foregroundStyle(Brand.action).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textStyle(.bodyStrong)
                Text(detail).textStyle(.callout, color: Brand.inkMuted).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var pick: some View {
        let sections = catalog?.sections ?? []
        let shown = shownCards
        return FlowScreen(onClose: close) {
            Question(tag: "Mailed for you · \(price)", title: "Which card for \(name)?",
                     subtitle: "Written in pen, stamped and mailed with your return address.", style: .title)
            TextLink(title: "How it works") { step = .intro }
                .padding(.leading, -8)
            // One category menu and one search, the way Handwrytten sorts its cards (Graham, Nov 22, 2026).
            HStack(spacing: Brand.space2) {
                if !sections.isEmpty {
                    Menu {
                        ForEach(sections, id: \.name) { s in
                            Button { section = s.name; searchText = "" } label: {
                                Text("\(s.name) (\(s.cards.count))")
                                if s.name == currentSection { Image(systemName: "checkmark") }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(currentSection ?? "Cards").textStyle(.bodyStrong).lineLimit(1)
                            Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Brand.ink)
                        .padding(.horizontal, Brand.space3)
                        .frame(minHeight: 44)
                        .overlay { RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous).strokeBorder(Brand.line) }
                    }
                    .accessibilityLabel("Category: \(currentSection ?? "Cards")")
                }
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Brand.inkMuted)
                    TextField("Search cards", text: $searchText)
                        .textStyle(.body)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Brand.inkMuted) }
                            .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, Brand.space3)
                .frame(minHeight: 44)
                .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
            }
            Text(shownCaption(shown.count)).textStyle(.caption, color: Brand.inkMuted)
            if shown.isEmpty {
                Text("Try another word, or pick a category.").textStyle(.callout, color: Brand.inkMuted)
            } else {
                cardGrid(shown)
            }
            if sections.isEmpty, searchText.isEmpty, let more = catalog?.more, !more.isEmpty {
                Eyebrow(text: "More cards, for any occasion").padding(.top, Brand.space3)
                cardGrid(more)
            }
        } footer: {
            if let card {
                TextLink(title: "See \(card.name.trimmingCharacters(in: .whitespaces)) larger") { viewing = card }
                    .frame(maxWidth: .infinity)
            }
            PrimaryButton(title: card.map { "Use \($0.name)" } ?? "Use this card") {
                if card == nil { card = shown.first ?? catalog?.cards.first }
                step = .message
            }
            .disabled(card == nil && shown.isEmpty)
        }
    }

    /// The menu's category, opening on the occasion's own.
    private var currentSection: String? {
        section ?? CardSearch.startingSection(own: catalog?.own, names: (catalog?.sections ?? []).map(\.name))
    }

    /// The cards to show: a search looks across every category; otherwise the chosen category's cards.
    private var shownCards: [MailCard] {
        let sections = catalog?.sections ?? []
        if sections.isEmpty {
            let all = (catalog?.cards ?? []) + (searchText.isEmpty ? [] : (catalog?.more ?? []))
            return all.filter { CardSearch.matches(searchText, name: $0.name, description: $0.description, category: nil) }
        }
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return sections.first { $0.name == currentSection }?.cards ?? catalog?.cards ?? []
        }
        var seen = Set<Int>(), out: [MailCard] = []
        for s in sections {
            for c in s.cards where !seen.contains(c.id)
                && CardSearch.matches(searchText, name: c.name, description: c.description, category: s.name) {
                seen.insert(c.id)
                out.append(c)
            }
        }
        return out
    }

    private func shownCaption(_ n: Int) -> String {
        let count = n == 1 ? "1 card" : "\(n) cards"
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty { return "\(count) for \u{201C}\(searchText)\u{201D}" }
        return currentSection.map { "\(count) · \($0)" } ?? count
    }

    private func cardGrid(_ list: [MailCard]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Brand.space3), GridItem(.flexible(), spacing: Brand.space3)],
                  spacing: Brand.space3) {
            ForEach(list) { c in
                // First tap picks the card; a tap on the picked card opens it full screen (Graham, Nov 25, 2026).
                Button { if card?.id == c.id { viewing = c } else { card = c } } label: {
                    VStack(spacing: 6) {
                        AsyncImage(url: c.safeCover) { phase in
                            switch phase {
                            case .success(let image): image.resizable().scaledToFit().padding(Brand.space2)
                            case .failure: CardPictureMissing()
                            default: ProgressView()
                            }
                        }
                        .frame(height: 170)
                        .frame(maxWidth: .infinity)
                        .background(Brand.card)
                        .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous)
                                .strokeBorder(card?.id == c.id ? Brand.action : Color.clear, lineWidth: 3)
                        }
                        Text(c.name.trimmingCharacters(in: .whitespaces)).textStyle(.caption, color: Brand.ink).lineLimit(2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(c.name)
                .accessibilityAddTraits(card?.id == c.id ? .isSelected : [])
                .accessibilityAction(named: "See it larger") { viewing = c }
                .contextMenu { Button("See it larger", systemImage: "arrow.up.left.and.arrow.down.right") { viewing = c } }
            }
        }
    }

    private var limit: Int { card?.characters ?? 300 }

    private var messageStep: some View {
        FlowScreen(onClose: { step = .pick }) {
            Question(title: "What should it say?", subtitle: "Handwrytten writes it in pen, word for word.", style: .title)
            VStack(alignment: .leading, spacing: 6) {
                Text("Message").font(TypeStyle.caption.strong).foregroundStyle(Brand.inkMuted)
                TextField(context.opening.replacingOccurrences(of: ",", with: "!"), text: $message, axis: .vertical)
                    .lineLimit(4...8)
                    .textStyle(.body)
                    .padding(Brand.space4)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                    .onChange(of: message) { _, m in
                        let room = max(0, limit - wishes.count)
                        if m.count > room { message = String(m.prefix(room)) }
                    }
                Text("\(max(0, limit - message.count - wishes.count)) characters left").textStyle(.caption, color: Brand.inkMuted)
            }
            LineField(label: "Signed", text: $wishes, placeholder: sender.firstName.isEmpty ? "Love, me" : "Love, \(sender.firstName)", showsDictation: false)
        } footer: {
            PrimaryButton(title: "Next") { step = .recipient }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func addressStep(title: String, subtitle: String, address: Binding<MailAddress>, next: Step, isRecipient: Bool) -> some View {
        FlowScreen(onClose: close) {
            Question(title: title, subtitle: subtitle, style: .title)
            AddressForm(address: address)
            if isRecipient, context.person != nil {
                if fromContacts {
                    Text("From \(name)'s contact card.").textStyle(.caption, color: Brand.inkMuted)
                } else if savedOnPerson {
                    Text("Saved for \(name) on this iPhone. Changes here are saved too.").textStyle(.caption, color: Brand.inkMuted)
                } else {
                    Toggle(isOn: $keepAddress) {
                        Text("Remember \(name)'s address for next time").textStyle(.body)
                    }
                    .tint(Brand.action)
                }
            }
        } footer: {
            PrimaryButton(title: "Next") {
                if !isRecipient { MailAddress.saved = sender }
                if isRecipient, !fromContacts, keepAddress || savedOnPerson, let person = context.person {
                    person.mailingAddress = recipient
                    try? person.managedObjectContext?.save()
                }
                step = next
            }
            .disabled(!address.wrappedValue.isComplete)
        }
    }

    private var review: some View {
        FlowScreen(onClose: close) {
            Question(title: "Mail it to \(name)?", style: .title)
            Card {
                if let card {
                    HStack(spacing: 14) {
                        AsyncImage(url: card.safeCover) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFit()
                                    .onAppear { cover = ImageRenderer(content: image.resizable().scaledToFit().frame(width: 600)).uiImage }
                            } else {
                                Brand.faceFills[0]
                            }
                        }
                            .frame(width: 64, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.name).textStyle(.bodyStrong)
                            Text(price).textStyle(.callout, color: Brand.inkMuted)
                        }
                    }
                }
                Text("\u{201C}\(message)\u{201D}").textStyle(.body)
                if !wishes.isEmpty { Text(wishes).textStyle(.body, color: Brand.inkMuted) }
            }
            ContextLine(text: "To: \(recipient.firstName) \(recipient.lastName), \(recipient.oneLine)")
            ContextLine(text: "From: \(sender.firstName) \(sender.lastName), \(sender.oneLine)")
            TextLink(title: "Change your return address") { step = .sender }
                .padding(.leading, -8)
            // Price, arrival and the terms are all on this screen before Apple Pay opens (design review, Nov 25, 2026).
            VStack(alignment: .leading, spacing: 2) {
                Text(MailArrival.arrivalLine(orderedOn: Date())).textStyle(.bodyStrong)
                if let line = MailArrival.christmasLine(today: Date(), orderBy: MailArrival.day(fromISO: catalog?.christmasOrderBy)) {
                    Text(line).textStyle(.callout, color: Brand.action)
                }
            }
            .accessibilityElement(children: .combine)
            // Names and the payment are named too (Fable N11; Graham approved Nov 25, 2026).
            Text("To mail it, Held Dear sends the message, both names and both addresses to Handwrytten, and your Apple Pay payment to Stripe. Nothing else leaves your iPhone.")
                .textStyle(.caption, color: Brand.inkMuted)
            Link("Terms of sale and refunds", destination: URL(string: "https://helddear.tangomike.app/terms")!)
                .font(.callout).foregroundStyle(Brand.action).frame(minHeight: 44)
            if catalog?.testMode == true {
                Text("Test mode: nothing is charged or mailed.").textStyle(.caption, color: Brand.action)
            }
        } footer: {
            if MailedCards.canPay {
                PayWithApplePayButton(.order) { pay() }
                    .payWithApplePayButtonStyle(.automatic)
                    .frame(height: 56)
                    .clipShape(Rectangle())
                    .disabled(paying)
            } else {
                Text("Apple Pay isn't set up on this iPhone. Add a card in Wallet to mail cards.")
                    .textStyle(.callout, color: Brand.inkMuted).multilineTextAlignment(.center)
            }
        }
    }

    private func done(_ mailing: String) -> some View {
        FlowScreen(onClose: close) {
            CirclesMark(size: 72).padding(.top, 80)
            // A test order says so in the title too, so it never reads as mailed (build 1057, Nov 25, 2026).
            let test = catalog?.testMode == true
            Question(tag: test ? "Test order" : "Done",
                     title: test ? "Test order placed" : (name.isEmpty ? "The card is on its way" : "\(name)'s card is on its way"),
                     subtitle: test ? "Nothing was charged or mailed." : "\(mailing). Written in pen, with your return address.")
            if let orderNumber {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order \(orderNumber)").textStyle(.bodyStrong)
                    Text("It's kept in You, under Mailed cards. For help: support@tangomike.app").textStyle(.callout, color: Brand.inkMuted)
                }
                .accessibilityElement(children: .combine)
            }
        } footer: {
            PrimaryButton(title: "OK", action: close)
        }
        .onAppear { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    private func failed(_ why: String) -> some View {
        FlowScreen(onClose: close) {
            Spacer(minLength: 100)
            Question(title: "That didn't go through", subtitle: why)
        } footer: {
            PrimaryButton(title: "Try again") { step = catalog == nil ? .loading : .review; if catalog == nil { Task { await load() } } }
            // Opened from a plan or a reason there is no choice screen to go back to, so it closes (build 1055).
            TextLink(title: "Choose something else") { if let go { go(.choose) } else { close() } }
        }
    }

    // MARK: Work

    private func load() async {
        guard catalog == nil else { return }
        do {
            let c = try await MailedCards.catalog(occasion: context.occasionKey)
            catalog = c
            card = c.cards.first
            if message.isEmpty { message = context.greeting }
            if wishes.isEmpty, !sender.firstName.isEmpty { wishes = "Love, \(sender.firstName)" }
            if let address = ContactsService.shared.mailAddress(contactID: context.person?.contactID) {
                recipient = address
                fromContacts = true
            } else if let saved = context.person?.mailingAddress {
                recipient = saved
                savedOnPerson = true
            }
            if recipient.firstName.isEmpty { recipient.firstName = name }
            // Stay on the how-it-works screen if it's showing; its button goes on to the cards.
            if step != .intro { step = c.cards.isEmpty ? .failed("No cards for this occasion are available right now.") : .pick }
        } catch {
            if step != .intro { step = .failed(error.localizedDescription) }
        }
    }

    private func pay() {
        guard let card, let catalog else { return }
        paying = true
        let m = message, w = wishes, r = recipient, s = sender, ref = reference, occ = context.occasionKey
        checkout.start(priceCents: catalog.priceCents, label: "Mailed card") { payment in
            do {
                return .success(try await MailedCards.placeOrder(reference: ref, card: card, message: m, wishes: w,
                                                                  recipient: r, sender: s, occasion: occ, payment: payment))
            } catch {
                return .failure(error)
            }
        } finish: { outcome in
            paying = false
            switch outcome {
            case .some(.success(let result)):
                context.onMailed(MailedCardRecord(cardName: card.name, message: m, cover: cover))
                orderNumber = result.orderId
                if let number = result.orderId {
                    MailedOrders.add(MailedOrder(id: ref, orderNumber: number, firstName: name, cardName: card.name,
                                                 orderedOn: Date(), mailing: result.mailing ?? "", test: catalog.testMode == true))
                }
                step = .done(result.mailing ?? "Mailing within 3 business days")
            case .some(.failure(let error)):
                // Keep the same reference unless the order is finished (nothing charged, or refunded), so a retry
                // can never charge or mail twice (M1, Nov 24, 2026).
                if (error as? MailedCards.Failure)?.startOver ?? true { reference = UUID().uuidString }
                step = .failed(error.localizedDescription)
            case .none:
                break   // Closed the Apple Pay sheet without paying: stay on review.
            }
        }
    }
}

/// A US mailing address, one field per line.
struct AddressForm: View {
    @Binding var address: MailAddress

    var body: some View {
        VStack(spacing: Brand.space2) {
            HStack(spacing: Brand.space2) {
                field("First name", $address.firstName, .givenName)
                field("Last name", $address.lastName, .familyName)
            }
            field("Street", $address.address1, .streetAddressLine1)
            field("Apt, suite (optional)", $address.address2, .streetAddressLine2)
            field("City", $address.city, .addressCity)
            HStack(spacing: Brand.space2) {
                field("State", $address.state, .addressState)
                    .onChange(of: address.state) { _, s in
                        let up = String(s.uppercased().filter(\.isLetter).prefix(2))
                        if up != s { address.state = up }
                    }
                field("ZIP", $address.zip, .postalCode).keyboardType(.numberPad)
            }
        }
    }

    private func field(_ label: String, _ text: Binding<String>, _ type: UITextContentType) -> some View {
        TextField(label, text: text)
            .textContentType(type)
            .textStyle(.body)
            .padding(.horizontal, Brand.space4)
            .frame(minHeight: 52)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
    }
}

/// An example of a mailed card: cream paper, the message in a handwriting face, in blue ink. It's drawn, not a
/// photo of a real card; the real one is written by machine with a ballpoint pen.
struct HandwrittenSample: View {
    let message: String
    let signature: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.custom("Bradley Hand", size: 19, relativeTo: .body))
                .foregroundStyle(Color(red: 0.13, green: 0.20, blue: 0.45))
                .lineSpacing(4)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
            Text(signature)
                .font(.custom("Bradley Hand", size: 19, relativeTo: .body))
                .foregroundStyle(Color(red: 0.13, green: 0.20, blue: 0.45))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.99, green: 0.97, blue: 0.92), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
        .rotationEffect(.degrees(-1.2))
        .overlay(alignment: .bottomTrailing) {
            Text("An example").textStyle(.caption, color: Brand.inkMuted).offset(y: 22)
        }
        .padding(.bottom, 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("An example card, handwritten in blue ink: \(message) \(signature)")
    }
}

/// A card picture that didn't load: a plain card shape, so the grid never spins forever (Nov 25, 2026).
struct CardPictureMissing: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "envelope").font(.system(size: 24, weight: .light))
            Text("Picture didn't load").font(.caption)
        }
        .foregroundStyle(Brand.inkMuted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A mailed card opened full screen: the front and, when Handwrytten has one, the inside. Pinch or double-tap to
/// zoom, drag to look around (Graham, Nov 25, 2026). The pictures come from Held Dear's server, like the grid's.
struct CardViewer: View {
    @Environment(\.dismiss) private var dismiss
    let card: MailCard
    var onUse: () -> Void

    private var title: String { card.name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if card.safeInside != nil {
                TabView {
                    front
                    inside
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            } else {
                front
            }
        }
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel("Close")
            .padding(.leading, Brand.space4).padding(.top, Brand.space2)
        }
        .overlay(alignment: .top) {
            Text(title).font(.callout.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .padding(.horizontal, 64)
                .padding(.top, Brand.space4)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) {
            Button {
                onUse()
                dismiss()
            } label: {
                Text("Use \(title)")
                    .font(.body.weight(.semibold)).foregroundStyle(.black)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(.horizontal, Brand.space5)
            .padding(.bottom, card.safeInside != nil ? Brand.space6 : Brand.space4)
        }
    }

    private var front: some View {
        Zoomable(label: "Front of \(title)") {
            AsyncImage(url: card.safeCover) { phase in page(phase) }
        }
    }

    private var inside: some View {
        Zoomable(label: "Inside of \(title)") {
            AsyncImage(url: card.safeInside) { phase in page(phase) }
        }
    }

    @ViewBuilder private func page(_ phase: AsyncImagePhase) -> some View {
        switch phase {
        case .success(let image): image.resizable().scaledToFit().padding(.vertical, 72)
        case .failure:
            VStack(spacing: Brand.space2) {
                Image(systemName: "envelope").font(.system(size: 32, weight: .light))
                Text("This picture didn't load. Close and try again.").font(.callout)
            }
            .foregroundStyle(.white.opacity(0.8))
        default: ProgressView().tint(.white)
        }
    }
}
