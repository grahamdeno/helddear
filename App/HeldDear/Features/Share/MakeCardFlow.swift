import PhotosUI
import SwiftUI

/// Make a digital card from You (story 2.11): what it's for, the photos, then the card to share. Made on the
/// phone and handed to the share sheet; nothing is uploaded, and the photos stay in the library.
struct MakeCardFlow: View {
    @EnvironmentObject var model: AppModel
    var close: () -> Void
    /// A saved draft or made card to open at the card step (Graham, Nov 21, 2026).
    var saved: SavedCard? = nil
    /// Opened from a person's card item (Nov 22, 2026): the occasion, heading and their photos already chosen, and
    /// a hook that marks the card done once it's shared.
    var preset: GreetingCard.Occasion? = nil
    var presetHeading: String? = nil
    var presetPhotos: [UIImage] = []
    var onShared: (() -> Void)? = nil
    /// The person the card is for, when opened from their page: lets "Write it for me" use what's saved about them.
    var person: Person? = nil

    @AppStorage("yourName") private var yourName = ""
    @AppStorage("cardSignature") private var signedAs = ""

    private enum Step { case occasion, photos, card }
    @State private var step: Step = .occasion
    @State private var occasion: GreetingCard.Occasion = .ownWords
    @State private var picks: [PhotosPickerItem] = []
    @State private var originals: [UIImage] = []
    @State private var framed: [UIImage] = []
    /// Each photo upright with its crop, so the crop can be slid to place the photo (Graham, Nov 21, 2026).
    @State private var framings: [(image: CGImage, rect: CGRect)] = []
    /// The photo being placed in the still preview.
    @State private var placing = 0
    @State private var dragStart: CGRect?
    @State private var shape: ShareCardView.Shape = .post
    @State private var moving = false
    @State private var heading = ""
    @State private var line = ""
    @State private var signature = ""
    @State private var sharing: [Any]?
    @State private var making: Double?
    @State private var failed = false
    @State private var loading = false
    @State private var savedID: UUID?
    @State private var madeBefore = false
    @State private var savedNote: String?

    var body: some View {
        ZStack {
            switch step {
            case .occasion: occasionStep
            case .photos: photosStep
            case .card: cardStep
            }
        }
        .animation(.easeOut(duration: 0.2), value: step)
        .task { restore() }
        .sheet(isPresented: Binding(get: { sharing != nil }, set: { if !$0 { sharing = nil } })) {
            ShareSheet(items: sharing ?? []) { _ in sharing = nil }
        }
    }

    private var occasionStep: some View {
        FlowScreen(onClose: close) {
            Question(title: "Make a digital card", subtitle: "Text it or post it. What's it for?", style: .title)
            VStack(spacing: 0) {
                ForEach(GreetingCard.choices(holidays: Holidays.enabled())) { o in
                    OptionRow(title: o.label, caption: o.heading.isEmpty ? "Your own heading" : o.heading) {
                        occasion = o
                        heading = o.heading
                        if signature.isEmpty { signature = GreetingCard.signature(signedAs.isEmpty ? yourName : signedAs) }
                        step = .photos
                    }
                }
            }
        }
    }

    private var photosStep: some View {
        FlowScreen(onClose: { step = .occasion }) {
            Question(title: "Pick photos", subtitle: "One for a still card, or up to \(GreetingCard.maxPhotos) for a slideshow.", style: .title)
            PhotosPicker(selection: $picks, maxSelectionCount: GreetingCard.maxPhotos, selectionBehavior: .ordered, matching: .images) {
                Text(originals.isEmpty ? "Choose photos" : "Change photos (\(originals.count))")
                    .font(.body.weight(.semibold)).foregroundStyle(Brand.ink)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay { RoundedRectangle(cornerRadius: Brand.radiusSm).strokeBorder(Brand.inkMuted, lineWidth: 1) }
            }
            if loading { ProgressView().tint(Brand.action) }
            if !originals.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(originals.enumerated()), id: \.offset) { _, img in
                            Image(uiImage: img).resizable().scaledToFill().frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
            }
        } footer: {
            PrimaryButton(title: originals.isEmpty ? "No photo, just words" : "Next") { Task { await reframe(); step = .card } }
        }
        .onChange(of: picks) { _, items in Task { await load(items) } }
    }

    private var content: GreetingCardContent {
        GreetingCardContent(heading: heading.trimmingCharacters(in: .whitespacesAndNewlines),
                            line: line.trimmingCharacters(in: .whitespacesAndNewlines),
                            signature: signature.trimmingCharacters(in: .whitespacesAndNewlines),
                            photos: framed, mark: occasion.holidayType)
    }

    private var duration: Double { GreetingCard.duration(photos: framed.count) }

    /// The still preview shows the photo being placed first.
    private var placingContent: GreetingCardContent {
        var c = content
        if c.photos.indices.contains(placing), placing > 0 {
            let p = c.photos.remove(at: placing)
            c.photos.insert(p, at: 0)
        }
        return c
    }

    private var cardStep: some View {
        FlowScreen(onClose: { step = .photos }) {
            Picker("Size", selection: $shape) {
                Text("Post").tag(ShareCardView.Shape.post)
                Text("Story").tag(ShareCardView.Shape.story)
            }
            .pickerStyle(.segmented)
            .onChange(of: shape) { _, s in
                // Re-place only when the crops don't fit the new shape (a saved card opens with its own crops).
                let fits = framings.allSatisfy { abs($0.rect.width / max(1, $0.rect.height) - s.aspect) < 0.03 }
                if !fits { Task { await reframe() } }
            }
            if framed.count > 1 && !moving {
                CardPhotoStrip(count: framed.count, selected: placing, thumb: { framed.indices.contains($0) ? framed[$0] : nil },
                               onSelect: { placing = $0 })
            }
            preview
            if !framed.isEmpty && !moving {
                Text(CardPhotos.placeHint(photoCount: framed.count))
                    .textStyle(.caption, color: Brand.inkMuted)
            }
            VStack(alignment: .leading, spacing: 0) {
                field("Heading", text: $heading, serif: true)
                field("Your line (optional)", text: $line, serif: true)
                if let person {
                    WriteForMe(kind: .cardLine, facts: { PersonFacts(person: person, moment: model.nextMoment(for: person)) }, text: $line)
                }
                field("Signed", text: $signature, serif: false)
                Toggle(isOn: $moving) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moving version").textStyle(.bodyStrong)
                        Text(framed.count > 1 ? "A slideshow of your photos, ending on the card." : "The words rise in over the photo.")
                            .textStyle(.caption, color: Brand.inkMuted)
                    }
                }
                .tint(Brand.action)
                .padding(.vertical, Brand.space3)
            }
            HStack(spacing: Brand.space3) {
                TextLink(title: madeBefore ? "Save changes" : "Save draft") { save(made: madeBefore) }
                    .padding(.leading, -8)
                if let savedNote { Text(savedNote).textStyle(.caption, color: Brand.inkMuted) }
            }
            if failed { Text("That didn't work. Try again.").textStyle(.bodyStrong, color: Brand.error) }
        } footer: {
            if let making {
                ProgressView(value: making) { Text("Making the video…").textStyle(.caption, color: Brand.inkMuted) }
                    .tint(Brand.action).frame(minHeight: 56)
            } else {
                PrimaryButton(title: moving ? "Make and share" : "Share") { share() }
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, serif: Bool) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .lineLimit(1...3)
            .returnEnds(text)
            .font(serif ? Brand.serif(18) : .body)
            .padding(.vertical, Brand.space3)
            .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
            .accessibilityLabel(placeholder)
    }

    private var preview: some View {
        let height = shape.height
        let card = content
        let length = duration
        return GeometryReader { geo in
            let s = geo.size.width / 390
            Group {
                if moving {
                    TimelineView(.animation) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: length + 1.5)
                        GreetingCardView(content: card, shape: shape, time: min(t, length))
                    }
                } else {
                    GreetingCardView(content: placingContent, shape: shape)
                }
            }
            .scaleEffect(s, anchor: .topLeading)
            .frame(width: 390 * s, height: height * s, alignment: .topLeading)
            .overlay(alignment: .top) {
                if !moving && !framed.isEmpty {
                    CardPhotoDrag(width: 390 * s, height: shape.photoHeight * s,
                                  onChanged: { slide(placing, by: $0, previewScale: s) }, onEnded: { dragStart = nil })
                }
            }
        }
        .aspectRatio(390 / height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel("Preview: \(card.heading). \(card.line) \(card.signature)")
    }

    private func load(_ items: [PhotosPickerItem]) async {
        loading = true
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { images.append(img) }
        }
        originals = images
        loading = false
    }

    /// Crops every photo to the card's shape with the faces placed.
    private func reframe() async {
        var out: [(image: CGImage, rect: CGRect)] = []
        for img in originals {
            if let f = await FaceFinder.shared.framing(of: img, aspect: shape.aspect) { out.append(f) }
        }
        framings = out
        placing = min(placing, max(0, out.count - 1))
        framed = out.compactMap { f in f.image.cropping(to: f.rect).map { UIImage(cgImage: $0) } }
    }

    /// Keeps the card on this iPhone: a draft to finish, or a made card to share again.
    private func save(made: Bool) {
        let card = SavedCard(id: savedID ?? UUID(), occasionID: occasion.id, heading: heading, line: line, signature: signature,
                             story: shape == .story, moving: moving, crops: framings.map(\.rect), made: made || madeBefore,
                             updated: Date())
        savedID = card.id
        madeBefore = card.made
        let photos = framings.map(\.image)
        Task.detached(priority: .utility) { CardDrafts.save(card, photos: photos) }
        savedNote = card.made ? "Saved to Your cards" : "Draft saved"
    }

    /// Opens a saved card where it was left.
    private func restore() {
        if saved == nil, let preset, step == .occasion {
            occasion = preset
            heading = presetHeading ?? preset.heading
            if signature.isEmpty { signature = GreetingCard.signature(signedAs.isEmpty ? yourName : signedAs) }
            if !presetPhotos.isEmpty { originals = presetPhotos; Task { await reframe() } }
            step = .photos
            return
        }
        guard let card = saved, savedID == nil else { return }
        savedID = card.id
        madeBefore = card.made
        occasion = GreetingCard.Occasion(id: card.occasionID) ?? .ownWords
        heading = card.heading
        line = card.line
        signature = card.signature
        shape = card.story ? .story : .post
        moving = card.moving
        let photos = CardDrafts.photos(card)
        originals = photos.map { UIImage(cgImage: $0) }
        framings = zip(photos, card.crops).map { (image: $0, rect: $1) }
        framed = framings.compactMap { f in f.image.cropping(to: f.rect).map { UIImage(cgImage: $0) } }
        step = .card
    }

    /// Slides one photo's crop by a drag on the preview, kept inside the photo.
    private func slide(_ index: Int, by translation: CGSize, previewScale s: CGFloat) {
        guard framings.indices.contains(index) else { return }
        let f = framings[index]
        let start = dragStart ?? f.rect
        if dragStart == nil { dragStart = f.rect }
        let rect = CardPhotos.slide(start, imageSize: CGSize(width: f.image.width, height: f.image.height),
                                    by: translation, scale: s)
        framings[index].rect = rect
        if let cg = f.image.cropping(to: rect), framed.indices.contains(index) { framed[index] = UIImage(cgImage: cg) }
    }

    private func share() {
        failed = false
        let card = content
        let length = duration
        let chosen = shape
        if moving {
            making = 0
            Task { @MainActor in
                do {
                    let url = try await ShareRender.video(height: chosen.height, duration: length, progress: { making = $0 }) { t in
                        GreetingCardView(content: card, shape: chosen, time: t)
                    }
                    making = nil
                    sharing = [url]
                    save(made: true)
                    onShared?()
                } catch {
                    making = nil
                    failed = true
                }
            }
        } else {
            let renderer = ImageRenderer(content: GreetingCardView(content: card, shape: chosen))
            renderer.scale = ShareRender.pixelWidth / 390
            if let image = renderer.uiImage { sharing = [image]; save(made: true); onShared?() } else { failed = true }
        }
    }
}
