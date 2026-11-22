import PhotosUI
import SwiftUI

/// Make a digital card from You (story 2.11): what it's for, the photos, then the card to share. Made on the
/// phone and handed to the share sheet; nothing is uploaded, and the photos stay in the library.
struct MakeCardFlow: View {
    @EnvironmentObject var model: AppModel
    var close: () -> Void

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

    var body: some View {
        ZStack {
            switch step {
            case .occasion: occasionStep
            case .photos: photosStep
            case .card: cardStep
            }
        }
        .animation(.easeOut(duration: 0.2), value: step)
        .sheet(isPresented: Binding(get: { sharing != nil }, set: { if !$0 { sharing = nil } })) {
            ShareSheet(items: sharing ?? []) { _ in sharing = nil }
        }
    }

    private var occasionStep: some View {
        FlowScreen(onClose: close) {
            Question(title: "Make a card", subtitle: "Text it or post it. What's it for?", style: .title)
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
            .onChange(of: shape) { _, _ in Task { await reframe() } }
            if framed.count > 1 && !moving {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Brand.space2) {
                        ForEach(framed.indices, id: \.self) { i in
                            Button { placing = i } label: {
                                Image(uiImage: framed[i]).resizable().scaledToFill()
                                    .frame(width: 52, height: 52)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(i == placing ? Brand.action : Color.clear, lineWidth: 2)
                                    }
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityLabel("Photo \(i + 1)")
                            .accessibilityAddTraits(i == placing ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }
            }
            preview
            if !framed.isEmpty && !moving {
                Text(framed.count > 1 ? "Drag a photo to place it. Pick another above." : "Drag the photo to place it.")
                    .textStyle(.caption, color: Brand.inkMuted)
            }
            VStack(alignment: .leading, spacing: 0) {
                field("Heading", text: $heading, serif: true)
                field("Your line (optional)", text: $line, serif: true)
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
                    Color.clear
                        .frame(width: 390 * s, height: shape.photoHeight * s)
                        .contentShape(Rectangle())
                        .highPriorityGesture(DragGesture(minimumDistance: 2)
                            .onChanged { slide(placing, by: $0.translation, previewScale: s) }
                            .onEnded { _ in dragStart = nil })
                        .accessibilityLabel("Photo")
                        .accessibilityHint("Drag to place the photo")
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

    /// Slides one photo's crop by a drag on the preview, kept inside the photo.
    private func slide(_ index: Int, by translation: CGSize, previewScale s: CGFloat) {
        guard framings.indices.contains(index) else { return }
        let f = framings[index]
        let start = dragStart ?? f.rect
        if dragStart == nil { dragStart = f.rect }
        let pixelsPerPoint = start.width / 390
        var rect = start
        rect.origin.x -= translation.width / s * pixelsPerPoint
        rect.origin.y -= translation.height / s * pixelsPerPoint
        rect.origin.x = min(max(0, rect.origin.x), CGFloat(f.image.width) - rect.width)
        rect.origin.y = min(max(0, rect.origin.y), CGFloat(f.image.height) - rect.height)
        rect = rect.integral
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
                } catch {
                    making = nil
                    failed = true
                }
            }
        } else {
            let renderer = ImageRenderer(content: GreetingCardView(content: card, shape: chosen))
            renderer.scale = ShareRender.pixelWidth / 390
            if let image = renderer.uiImage { sharing = [image] } else { failed = true }
        }
    }
}
