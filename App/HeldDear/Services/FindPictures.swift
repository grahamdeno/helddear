import SwiftUI
import UIKit

/// Each find's picture comes from its own shop page's preview (Graham, Nov 21, 2026): asked once through
/// LinkPreviews, then kept on the phone so the page isn't asked again. Nothing goes to Held Dear.
@MainActor
final class FindPictures: ObservableObject {
    static let shared = FindPictures()
    @Published private(set) var images: [String: UIImage] = [:]
    private var asked: Set<String> = []

    private var folder: URL {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "FindPictures")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func file(_ find: Find) -> URL { folder.appending(path: "\(find.id).jpg") }

    func image(for find: Find) -> UIImage? {
        if let image = images[find.id] { return image }
        if let name = find.photo, let image = UIImage(named: name) { return image }
        return nil
    }

    /// Loads the kept picture, or asks the shop's page once.
    func load(_ find: Find) async {
        guard images[find.id] == nil, !asked.contains(find.id) else { return }
        asked.insert(find.id)
        if let data = try? Data(contentsOf: file(find)), let image = UIImage(data: data) {
            images[find.id] = image
            return
        }
        guard let url = URL(string: find.url) else { return }
        guard let image = await LinkPreviews.fetch(url).image, image.size.width >= 120 else { return }
        let small = image.preparingThumbnail(of: Self.fit(image.size, max: 900)) ?? image
        images[find.id] = small
        if let data = small.jpegData(compressionQuality: 0.82) { try? data.write(to: file(find), options: .atomic) }
    }

    private static func fit(_ size: CGSize, max side: CGFloat) -> CGSize {
        let scale = min(1, side / Swift.max(size.width, size.height))
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

/// A find's picture, or the maker's name on stone while it loads or when the shop has none.
struct FindPicture: View {
    let find: Find
    @ObservedObject private var pictures = FindPictures.shared

    var body: some View {
        Rectangle().fill(Brand.card)
            .overlay {
                if let image = pictures.image(for: find) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Text(find.maker).font(Brand.serif(17, relativeTo: .body, italic: true))
                        .foregroundStyle(Brand.inkMuted).multilineTextAlignment(.center).padding(Brand.space3)
                }
            }
            .clipped()
            .accessibilityHidden(true)
            .task { await pictures.load(find) }
    }
}
