import PhotosUI
import SwiftUI

/// Share a person's day as an image or a short video (approved Nov 21, 2026). Everything is made on the phone and
/// handed to the iOS share sheet; nothing goes to a server. Age is off every time the screen opens.
struct ShareDayFlow: View {
    @EnvironmentObject var model: AppModel
    let moment: Moment
    var close: () -> Void

    @State private var shape: ShareCardView.Shape = .post
    @State private var moving = false
    @State private var addAge = false
    @State private var note = ""
    /// The anniversary's couple banner, used until a photo is chosen.
    @State private var photo: UIImage?
    @State private var storyPhoto: UIImage?
    // Choosing and placing photos, the same way as the digital card (Nov 22, 2026): up to five, in the order tapped,
    // the first for the still card; the drag places the one tapped last.
    @State private var files: [String] = []
    @State private var thumbs: [String: UIImage] = [:]
    /// Photos added from the library (or the contact's photo), after the person's photos in the row.
    @State private var extras: [UIImage] = []
    @State private var picked: [Int] = []
    @State private var placing: Int?
    @State private var libraryPick: PhotosPickerItem?
    @State private var framings: [Int: (image: CGImage, rect: CGRect)] = [:]
    @State private var placed: [Int: UIImage] = [:]
    @State private var dragStart: CGRect?
    @AppStorage("yourName") private var yourName = ""
    @AppStorage("cardSignature") private var signedAs = ""
    @State private var signature = ""
    @State private var sharing: [Any]?
    @State private var making: Double?
    @State private var failed = false

    private var name: String { DisplayName.plain(moment.person?.name ?? "") }
    /// "Ana & Marco" on an anniversary card (Graham, Nov 21, 2026).
    private var cardName: String { model.pairName(for: moment) ?? name }

    private var content: ShareCardContent {
        ShareCardContent(name: cardName,
                         subline: ShareCardLayout.subline(type: moment.type, partner: moment.occasion?.partnerName,
                                                          count: moment.turning, addAge: addAge),
                         date: moment.dueDate, note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                         photos: photos, signature: signature.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var photos: [UIImage] {
        let chosen = picked.compactMap { placed[$0] }
        if !chosen.isEmpty { return chosen }
        return (shape == .post ? photo : storyPhoto).map { [$0] } ?? []
    }

    /// The still preview shows the photo being placed.
    private var previewContent: ShareCardContent {
        var c = content
        if let p = placing, let img = placed[p], picked.count > 1 {
            c.photos = [img] + c.photos.filter { $0 !== img }
        }
        return c
    }

    private var rowCount: Int { files.count + extras.count }

    private func thumb(_ i: Int) -> UIImage? {
        i < files.count ? thumbs[files[i]] : (extras.indices.contains(i - files.count) ? extras[i - files.count] : nil)
    }

    var body: some View {
        FlowScreen(onClose: close) {
            Question(title: "Share \(name)'s day", subtitle: "Made on your phone. Nothing is uploaded.", style: .title)
            Picker("Size", selection: $shape) {
                Text("Post").tag(ShareCardView.Shape.post)
                Text("Story").tag(ShareCardView.Shape.story)
            }
            .pickerStyle(.segmented)
            .onChange(of: shape) { _, _ in Task { await reframe() } }
            CardPhotoStrip(count: rowCount, selected: placing, thumb: thumb, onSelect: tap, library: $libraryPick, order: picked)
            Text(picked.count > 1 ? "\(picked.count) photos: a slideshow in the moving version. The first is the still card."
                                  : "Tap more photos for a slideshow, up to \(ShareCardLayout.maxPhotos).")
                .textStyle(.caption, color: Brand.inkMuted)
            preview
            if placing.flatMap({ framings[$0] }) != nil && !moving {
                Text(CardPhotos.placeHint(photoCount: 1)).textStyle(.caption, color: Brand.inkMuted)
            }
            VStack(alignment: .leading, spacing: 0) {
                TextField("Add a line (optional)", text: $note, axis: .vertical)
                    .lineLimit(1...2)
                    .returnEnds($note)
                    .font(Brand.serif(17, italic: true))
                    .padding(.vertical, Brand.space3)
                    .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
                TextField("Signed (optional)", text: $signature)
                    .font(.body)
                    .padding(.vertical, Brand.space3)
                    .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
                    .accessibilityLabel("Signed")
                if let person = moment.person {
                    // Public, so only the name and the day go in (Nov 22, 2026).
                    WriteForMe(kind: .shareLine, facts: {
                        var f = PersonFacts(name: DisplayName.plain(person.name), occasion: moment.type)
                        if addAge { f.countLine = moment.countLine }
                        return f
                    }, text: $note)
                }
                if moment.turning != nil && moment.type.countLine(moment.turning) != nil {
                    Toggle(isOn: $addAge) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add age").textStyle(.bodyStrong)
                            Text("Off each time. A post can be seen by anyone.").textStyle(.caption, color: Brand.inkMuted)
                        }
                    }
                    .tint(Brand.action)
                    .padding(.vertical, Brand.space3)
                }
                Toggle(isOn: $moving) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moving version").textStyle(.bodyStrong)
                        Text(picked.count > 1 ? "Your photos as a slideshow, then the line draws and the dot lands on the day."
                                              : "A 6-second video: the line draws and the dot lands on the day.")
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
                    .tint(Brand.action)
                    .frame(minHeight: 56)
            } else {
                // "Share" read as if tapping would post it (Graham, Nov 22, 2026): say what happens next.
                VStack(spacing: Brand.space2) {
                    PrimaryButton(title: "Choose where it goes") { share() }
                    Text("Nothing is sent until you pick.").textStyle(.caption, color: Brand.inkMuted)
                }
            }
        }
        .task {
            if signature.isEmpty { signature = GreetingCard.signature(signedAs.isEmpty ? yourName : signedAs) }
            let person = moment.person
            files = CardPhotos.order(files: person?.photoFiles ?? [], top: person?.photoFiles.last)
            if moment.type == .anniversary, model.pairPartner(for: moment) != nil || OccasionPhotos.file(for: moment.occasion?.id) != nil {
                // The couple banner stays until a photo is chosen from the row.
                photo = await model.anniversaryBanner(for: moment, aspect: ShareCardView.Shape.post.aspect)
                storyPhoto = await model.anniversaryBanner(for: moment, aspect: ShareCardView.Shape.story.aspect)
            } else if !files.isEmpty {
                await tapAsync(0)
            } else if let contact = ContactsService.shared.photo(contactID: person?.contactID) {
                extras.append(contact)
                await tapAsync(files.count + extras.count - 1)
            }
            await loadThumbs()
        }
        .onChange(of: libraryPick) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    extras.append(image)
                    await tapAsync(rowCount - 1)
                }
                libraryPick = nil
            }
        }
        .sheet(isPresented: Binding(get: { sharing != nil }, set: { if !$0 { sharing = nil } })) {
            ShareSheet(items: sharing ?? []) { _ in sharing = nil }
        }
    }

    /// The still image, scaled to the screen. The moving version plays here too.
    private var preview: some View {
        let height = shape.height
        return GeometryReader { geo in
            let s = geo.size.width / 390
            Group {
                if moving {
                    TimelineView(.animation) { tl in
                        let length = ShareCardLayout.duration(photos: content.photos.count)
                        let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: length + 1.5)
                        ShareCardView(content: content, shape: shape, time: min(t, length))
                    }
                } else {
                    ShareCardView(content: previewContent, shape: shape)
                }
            }
            .scaleEffect(s, anchor: .topLeading)
            .frame(width: 390 * s, height: height * s, alignment: .topLeading)
            .overlay(alignment: .top) {
                if placing.flatMap({ framings[$0] }) != nil && !moving {
                    CardPhotoDrag(width: 390 * s, height: shape.photoHeight * s,
                                  onChanged: { slide(by: $0, scale: s) }, onEnded: { dragStart = nil })
                }
            }
        }
        .aspectRatio(390 / height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel("Preview: \(name), \(content.subline), \(ShareCardLayout.dotLabel(moment.dueDate))")
    }

    /// A tap in the row: adds the photo to the slideshow (and places it), places one already in, or takes out the
    /// one being placed.
    private func tap(_ i: Int) { Task { await tapAsync(i) } }

    private func tapAsync(_ i: Int) async {
        if picked.contains(i) && placing != i { placing = i; return }
        picked = ShareCardLayout.toggled(picked, i)
        if picked.contains(i) {
            placing = i
            await frame(i)
        } else {
            placing = picked.last
        }
    }

    /// Crops one photo to the card's shape around the face (or the chosen focus); the drag then moves it.
    private func frame(_ i: Int) async {
        let f: (image: CGImage, rect: CGRect)?
        if i < files.count {
            f = await FaceFinder.shared.framing(file: files[i], aspect: shape.aspect)
        } else if extras.indices.contains(i - files.count) {
            f = await FaceFinder.shared.framing(of: extras[i - files.count], aspect: shape.aspect)
        } else {
            f = nil
        }
        framings[i] = f
        placed[i] = f.flatMap { f in f.image.cropping(to: f.rect).map { UIImage(cgImage: $0) } }
    }

    /// The shape changed: every chosen photo is cropped again.
    private func reframe() async {
        for i in picked { await frame(i) }
    }

    private func slide(by translation: CGSize, scale: CGFloat) {
        guard let i = placing, let f = framings[i] else { return }
        let start = dragStart ?? f.rect
        if dragStart == nil { dragStart = f.rect }
        let rect = CardPhotos.slide(start, imageSize: CGSize(width: f.image.width, height: f.image.height), by: translation, scale: scale)
        framings[i] = (f.image, rect)
        if let cg = f.image.cropping(to: rect) { placed[i] = UIImage(cgImage: cg) }
    }

    /// Small copies for the row, loaded off the main thread, newest year first as ordered.
    private func loadThumbs() async {
        for file in files.prefix(60) where thumbs[file] == nil {
            let small = await Task.detached(priority: .utility) { () -> UIImage? in
                PhotoStore.load(file).map { PhotoStore.downscale($0, maxSide: 160) }
            }.value
            if let small { thumbs[file] = small }
        }
    }

    private func share() {
        failed = false
        let made = content
        if moving {
            making = 0
            Task { @MainActor in
                do {
                    let url = try await ShareRender.video(made, shape: shape) { making = $0 }
                    making = nil
                    sharing = [url]
                } catch {
                    making = nil
                    failed = true
                }
            }
        } else if let image = ShareRender.still(made, shape: shape) {
            sharing = [image]
        } else {
            failed = true
        }
    }
}
