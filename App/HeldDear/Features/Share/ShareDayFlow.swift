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
    @State private var photo: UIImage?
    @State private var storyPhoto: UIImage?
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
                         photo: shape == .post ? photo : storyPhoto)
    }

    var body: some View {
        FlowScreen(onClose: close) {
            Question(title: "Share \(name)'s day", subtitle: "Made on your phone. Nothing is uploaded.", style: .title)
            Picker("Size", selection: $shape) {
                Text("Post").tag(ShareCardView.Shape.post)
                Text("Story").tag(ShareCardView.Shape.story)
            }
            .pickerStyle(.segmented)
            preview
            VStack(alignment: .leading, spacing: 0) {
                TextField("Add a line (optional)", text: $note, axis: .vertical)
                    .lineLimit(1...2)
                    .returnEnds($note)
                    .font(Brand.serif(17, italic: true))
                    .padding(.vertical, Brand.space3)
                    .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
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
                        Text("A 6-second video: the line draws and the dot lands on the day.").textStyle(.caption, color: Brand.inkMuted)
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
                PrimaryButton(title: moving ? "Make and share" : "Share") { share() }
            }
        }
        .task {
            if moment.type == .anniversary, model.pairPartner(for: moment) != nil || OccasionPhotos.file(for: moment.occasion?.id) != nil {
                photo = await model.anniversaryBanner(for: moment, aspect: ShareCardView.Shape.post.aspect)
                storyPhoto = await model.anniversaryBanner(for: moment, aspect: ShareCardView.Shape.story.aspect)
            } else {
                photo = await FaceFinder.shared.banner(for: moment.person, aspect: ShareCardView.Shape.post.aspect)
                storyPhoto = await FaceFinder.shared.banner(for: moment.person, aspect: ShareCardView.Shape.story.aspect)
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
                        let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: ShareCardLayout.duration + 1.5)
                        ShareCardView(content: content, shape: shape, time: min(t, ShareCardLayout.duration))
                    }
                } else {
                    ShareCardView(content: content, shape: shape)
                }
            }
            .scaleEffect(s, anchor: .topLeading)
            .frame(width: 390 * s, height: height * s, alignment: .topLeading)
        }
        .aspectRatio(390 / height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel("Preview: \(name), \(content.subline), \(ShareCardLayout.dotLabel(moment.dueDate))")
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
