import SwiftUI

/// A card for any reason, not only a day (story 2.8, approved Nov 21, 2026). One decision per screen: the reason,
/// then make it (free, sent in Messages) or mail it (Apple Pay), then the card itself.
struct ReasonCardFlow: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var purchases = Purchases.shared
    let person: Person
    var close: () -> Void

    private enum Step: Equatable { case reason, how, photo, design, mail, sent }
    @State private var step: Step = .reason
    @State private var reason: CardReason = .justBecause
    @State private var choices: [PhotoChoice] = []
    @State private var selected: String?
    @State private var design: CardDesign = .hearth
    @State private var cardImage: UIImage?
    @State private var composing = false
    @State private var sharing = false
    @State private var failed = false

    private var name: String { DisplayName.plain(person.name) }
    private var photo: UIImage? { choices.first { $0.id == selected }?.image }
    private var content: CardContent {
        CardContent(name: name, photo: photo, words: nil, age: nil, date: Date(), occasion: .event, opening: reason.opening)
    }

    var body: some View {
        ZStack {
            switch step {
            case .reason: reasonStep
            case .how: howStep
            case .photo: photoStep
            case .design: designStep
            case .mail:
                MailCardFlow(context: MailContext(person: person, occasionKey: reason.serverKey, opening: reason.opening,
                                                  greeting: reason.greeting(name: name),
                                                  onMailed: { _ in model.recordCard(person, reason: reason) }),
                             close: close)
            case .sent: sentStep
            }
        }
        .animation(Motion.animation(.easeOut(duration: 0.22)), value: step)
        .onAppear {
            choices = model.photoChoices(for: person)
            selected = choices.first?.id
        }
        .fullScreenCover(isPresented: $composing) {
            MessageComposer(recipients: [model.phone(for: person)].compactMap { $0 }, body: "", image: cardImage) { result in
                composing = false
                switch result {
                case .sent: finishMade()
                case .failed: failed = true
                default: break
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $sharing) {
            ShareSheet(items: [cardImage as Any].compactMap { $0 }) { completed in
                sharing = false
                if completed { finishMade() }
            }
        }
    }

    private var reasonStep: some View {
        FlowScreen(onClose: close) {
            Question(title: "A card for \(name)", subtitle: "What's it for?", style: .title)
            VStack(spacing: 0) {
                ForEach(CardReason.allCases) { r in
                    OptionRow(title: r.label, caption: r.greeting(name: name)) {
                        reason = r
                        step = AppFeatures.mailedCards ? .how : .photo
                    }
                }
            }
        }
    }

    private var howStep: some View {
        FlowScreen(onClose: { step = .reason }) {
            Question(title: "Make it or mail it?", subtitle: reason.label, style: .title)
            VStack(spacing: 0) {
                OptionRow(title: "Make it", caption: "Free. A card with a photo, sent in Messages") { step = .photo }
                OptionRow(title: "Mail it", caption: "A real card, handwritten and mailed. Paid with Apple Pay") { step = .mail }
            }
        }
    }

    private var photoStep: some View {
        FlowScreen(onClose: { step = AppFeatures.mailedCards ? .how : .reason }) {
            Question(title: choices.isEmpty ? "No photo of \(name) yet" : "Pick a photo for \(name)",
                     subtitle: choices.isEmpty ? "The card uses \(name)'s initials." : "It goes on the card.", style: .title)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(choices) { c in
                    Button { selected = c.id } label: {
                        Image(uiImage: c.image).resizable().scaledToFill()
                            .frame(height: 150).frame(maxWidth: .infinity).clipped()
                            .overlay {
                                RoundedRectangle(cornerRadius: Brand.radiusSm)
                                    .strokeBorder(selected == c.id ? Brand.action : .clear, lineWidth: 3)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSm))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(c.label)
                    .accessibilityAddTraits(selected == c.id ? [.isButton, .isSelected] : .isButton)
                }
            }
        } footer: {
            PrimaryButton(title: "Next") { step = .design }
        }
    }

    private var designStep: some View {
        FlowScreen(onClose: { step = .photo }) {
            Question(title: "Which card?", subtitle: "Swipe to see them.", style: .title)
            TabView(selection: $design) {
                ForEach(CardDesign.allCases.filter { $0.isFree || purchases.hasLifetime }) { d in
                    CardView(design: d, content: content)
                        .scaleEffect(0.58)
                        .frame(width: CardView.size.width * 0.58, height: CardView.size.height * 0.58)
                        .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
                        .tag(d)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: CardView.size.height * 0.58 + 40)
            if failed { Text("That didn't go through.").textStyle(.bodyStrong, color: Brand.error) }
        } footer: {
            PrimaryButton(title: "Send to \(name)") {
                failed = false
                cardImage = CardRenderer.image(design: design, content: content)
                if MessageComposer.canSend { composing = true } else { sharing = true }
            }
        }
    }

    private var sentStep: some View {
        FlowScreen(onClose: close) {
            Question(tag: "Sent", title: "\(reason.label) card sent", subtitle: "It's in \(name)'s yearly record.", style: .title)
        } footer: {
            PrimaryButton(title: "Done", action: close)
        }
    }

    private func finishMade() {
        model.recordCard(person, reason: reason, cardImage: cardImage)
        step = .sent
    }
}
