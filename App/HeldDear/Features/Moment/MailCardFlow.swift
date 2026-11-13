import PassKit
import SwiftUI
import UIKit

/// "Mail a real card": Handwrytten writes the message in pen and mails it with the user's return address.
/// Pick a card, write the message, check the addresses, pay with Apple Pay. One decision per screen.
struct MailCardFlow: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    var go: (MomentStep) -> Void
    var close: () -> Void

    enum Step: Equatable { case loading, pick, message, recipient, sender, review, done(String), failed(String) }
    @State private var step: Step = .loading
    @State private var catalog: MailedCards.Catalog?
    @State private var card: MailCard?
    @State private var message = ""
    @State private var wishes = ""
    @State private var recipient = MailAddress()
    @State private var sender = MailAddress.saved ?? MailAddress()
    @State private var paying = false
    @State private var checkout = ApplePayCheckout()
    @State private var reference = UUID().uuidString

    private var name: String { moment.person?.name ?? "" }
    private var price: String {
        let cents = catalog?.priceCents ?? 699
        return (Double(cents) / 100).formatted(.currency(code: "USD"))
    }

    var body: some View {
        ZStack {
            switch step {
            case .loading: loading
            case .pick: pick
            case .message: messageStep
            case .recipient: addressStep(title: "Where does it go?", subtitle: "\(name)'s mailing address.", address: $recipient, next: .sender)
            case .sender: addressStep(title: "Your return address", subtitle: "It goes on the envelope. Kept on this iPhone for next time.", address: $sender, next: .review)
            case .review: review
            case .done(let mailing): done(mailing)
            case .failed(let why): failed(why)
            }
        }
        .animation(.easeOut(duration: 0.22), value: step)
        .task { await load() }
    }

    // MARK: Steps

    private var loading: some View {
        FlowScreen(onClose: close) {
            Spacer(minLength: 120)
            ProgressView().frame(maxWidth: .infinity)
            Text("Finding cards…").textStyle(.callout, color: Brand.inkMuted).frame(maxWidth: .infinity)
        }
    }

    private var pick: some View {
        let cards = catalog?.cards ?? []
        return FlowScreen(onClose: close) {
            Question(tag: "Mailed for you · \(price)", title: "Which card for \(name)?",
                     subtitle: "Written in pen, stamped and mailed with your return address.", style: .title)
            TabView(selection: Binding(get: { card?.id ?? cards.first?.id ?? 0 },
                                       set: { id in card = cards.first { $0.id == id } })) {
                ForEach(cards) { c in
                    VStack(spacing: Brand.space2) {
                        AsyncImage(url: c.cover) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: Brand.radiusSm).fill(Brand.faceFills[0])
                                .overlay(ProgressView())
                        }
                        .frame(height: 340)
                        .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
                        Text(c.name).textStyle(.bodyStrong)
                    }
                    .tag(c.id)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(c.name)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(height: 420)
        } footer: {
            PrimaryButton(title: "Use this card") {
                if card == nil { card = cards.first }
                step = .message
            }
        }
    }

    private var limit: Int { card?.characters ?? 300 }

    private var messageStep: some View {
        FlowScreen(onClose: { step = .pick }) {
            Question(title: "What should it say?", subtitle: "Handwrytten writes it in pen, word for word.", style: .title)
            VStack(alignment: .leading, spacing: 6) {
                Text("Message").font(TypeStyle.caption.strong).foregroundStyle(Brand.inkMuted)
                TextField(moment.type.cardOpening.replacingOccurrences(of: ",", with: "!"), text: $message, axis: .vertical)
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
            LineField(label: "Signed", text: $wishes, placeholder: "Love, Graham", showsDictation: false)
        } footer: {
            PrimaryButton(title: "Next") { step = .recipient }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func addressStep(title: String, subtitle: String, address: Binding<MailAddress>, next: Step) -> some View {
        FlowScreen(onClose: close) {
            Question(title: title, subtitle: subtitle, style: .title)
            AddressForm(address: address)
        } footer: {
            PrimaryButton(title: "Next") {
                if next == .review { MailAddress.saved = sender }
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
                        AsyncImage(url: card.cover) { $0.resizable().scaledToFit() } placeholder: { Brand.faceFills[0] }
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
            Text("To mail it, Held Dear sends this card's message and these two addresses to Handwrytten. Nothing else leaves your iPhone.")
                .textStyle(.caption, color: Brand.inkMuted)
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
            Question(tag: "Done", title: "\(name)'s card is on its way",
                     subtitle: "\(mailing). Written in pen, with your return address.")
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
            TextLink(title: "Choose something else") { go(.choose) }
        }
    }

    // MARK: Work

    private func load() async {
        guard catalog == nil else { return }
        do {
            let c = try await MailedCards.catalog(occasion: moment.type.rawValue)
            catalog = c
            card = c.cards.first
            if message.isEmpty { message = moment.type.greeting(name: name) }
            if wishes.isEmpty, !sender.firstName.isEmpty { wishes = "Love, \(sender.firstName)" }
            if let address = ContactsService.shared.mailAddress(contactID: moment.person?.contactID) { recipient = address }
            if recipient.firstName.isEmpty { recipient.firstName = name }
            step = c.cards.isEmpty ? .failed("No cards for this occasion are available right now.") : .pick
        } catch {
            step = .failed(error.localizedDescription)
        }
    }

    private func pay() {
        guard let card, let catalog else { return }
        paying = true
        let m = message, w = wishes, r = recipient, s = sender, ref = reference, occ = moment.type.rawValue
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
                model.mailedCard(moment, cardName: card.name)
                step = .done(result.mailing ?? "Mailing within 2 business days")
            case .some(.failure(let error)):
                reference = UUID().uuidString
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
