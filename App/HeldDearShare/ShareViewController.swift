import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// B2 from the share sheet: preview of the link, photo or text, then "Who is this for?". Tapping a person saves it.
/// The wish goes to the App Group inbox; Held Dear files it on that person the next time it opens.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let model = ShareModel()
        let root = ShareView(model: model, onDone: { [weak self] in self?.finish() }, onCancel: { [weak self] in self?.cancel() })
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        model.load(from: extensionContext?.inputItems as? [NSExtensionItem] ?? [])
    }

    private func finish() { extensionContext?.completeRequest(returningItems: nil) }
    private func cancel() { extensionContext?.cancelRequest(withError: NSError(domain: "HeldDear", code: 0)) }
}

@MainActor
final class ShareModel: ObservableObject {
    @Published var title = ""
    @Published var url: URL?
    @Published var image: UIImage?
    @Published var people: [SharedPerson] = []
    @Published var showEveryone = false

    init() {
        people = AppGroup.read([SharedPerson].self, from: AppGroup.peopleURL) ?? []
    }

    func load(from items: [NSExtensionItem]) {
        for item in items {
            if let t = item.attributedContentText?.string, !t.isEmpty, title.isEmpty { title = t }
            if let t = item.attributedTitle?.string, !t.isEmpty { title = t }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        Task { @MainActor in
                            guard let url else { return }
                            if url.isFileURL {
                                if let data = try? Data(contentsOf: url), let img = UIImage(data: data) { self.image = img }
                            } else {
                                self.url = url
                                if self.title.isEmpty { self.title = url.host() ?? url.absoluteString }
                            }
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    _ = provider.loadObject(ofClass: UIImage.self) { obj, _ in
                        Task { @MainActor in if let img = obj as? UIImage { self.image = img } }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    _ = provider.loadObject(ofClass: String.self) { text, _ in
                        Task { @MainActor in
                            guard let text else { return }
                            // Text that is only a link is treated as the link.
                            if let link = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), link.scheme?.hasPrefix("http") == true {
                                self.url = link
                                if self.title.isEmpty { self.title = link.host() ?? text }
                            } else if self.title.isEmpty || self.title == self.url?.host() {
                                self.title = text
                            }
                        }
                    }
                }
            }
        }
    }

    var shownPeople: [SharedPerson] {
        let sorted = people.sorted { a, b in
            if a.isInner != b.isInner { return a.isInner }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return showEveryone ? sorted : Array(sorted.filter(\.isInner).prefix(8))
    }

    func save(for person: SharedPerson) {
        var imageFile: String?
        if let image {
            let name = UUID().uuidString + ".jpg"
            let scaled = Self.downscale(image, maxSide: 1600)
            if let data = scaled.jpegData(compressionQuality: 0.85),
               (try? data.write(to: AppGroup.inboxDir.appendingPathComponent(name))) != nil {
                imageFile = name
            }
        }
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let wish = InboxWish(id: UUID(), personID: person.id, text: text.isEmpty ? (url?.absoluteString ?? "A saved idea") : text,
                             url: url?.absoluteString, imageFile: imageFile, capturedAt: Date())
        AppGroup.write(wish, to: AppGroup.inboxDir.appendingPathComponent("\(wish.id.uuidString).json"))
    }

    static func downscale(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let side = max(image.size.width, image.size.height)
        guard side > maxSide else { return image }
        let scale = maxSide / side
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

struct ShareView: View {
    @ObservedObject var model: ShareModel
    var onDone: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button("Cancel", action: onCancel).font(TypeStyle.callout.strong).foregroundStyle(Brand.action)
                Spacer()
            }
            HStack(spacing: 14) {
                Group {
                    if let image = model.image {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Image(systemName: model.url == nil ? "text.quote" : "link")
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(Brand.ink)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Brand.faceFills[0])
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: Brand.radiusMd, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    TextField("What is it?", text: $model.title, axis: .vertical)
                        .lineLimit(1...3)
                        .font(TypeStyle.body.strong).foregroundStyle(Brand.ink)
                    if let host = model.url?.host() {
                        Text(host.replacingOccurrences(of: "www.", with: "")).textStyle(.caption, color: Brand.inkMuted)
                    }
                }
            }
            Text("Who is this for?").textStyle(.headline)
            if model.people.isEmpty {
                Text("Open Held Dear once to add your people, then share again.").textStyle(.body, color: Brand.inkMuted)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 14) {
                        ForEach(model.shownPeople) { p in
                            Button {
                                model.save(for: p)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onDone()
                            } label: {
                                VStack(spacing: 6) {
                                    Face(name: p.name, initials: initials(p.name), image: nil, size: 56)
                                    Text(p.name).font(TypeStyle.caption.strong).foregroundStyle(Brand.ink).lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Save for \(p.name)")
                        }
                    }
                    if !model.showEveryone {
                        Button("Someone else") { model.showEveryone = true }
                            .font(TypeStyle.callout.strong).foregroundStyle(Brand.action)
                            .frame(minHeight: 44).frame(maxWidth: .infinity)
                    }
                }
            }
            Text("Tapping a person saves it.").textStyle(.caption, color: Brand.inkMuted).frame(maxWidth: .infinity)
        }
        .padding(Brand.space5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Brand.page.ignoresSafeArea())
        .onAppear { if model.people.allSatisfy({ !$0.isInner }) { model.showEveryone = true } }
    }

    private func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
