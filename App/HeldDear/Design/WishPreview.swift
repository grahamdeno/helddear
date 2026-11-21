import SwiftUI

/// A saved idea as a small link preview (Nov 21, 2026): its picture, its title (never a raw web address), and where
/// it's from. A link without a title yet shows the shop's name while the preview loads.
struct WishPreview: View {
    let wish: Wish
    var bold = false
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: Brand.space3) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textStyle(bold ? .bodyStrong : .body).lineLimit(3).multilineTextAlignment(.leading)
                Text(caption).textStyle(.caption, color: Brand.inkMuted).lineLimit(1)
            }
        }
        .task(id: wish.id) { model.addPreview(to: wish) }
    }

    private var link: URL? { wish.url.flatMap(URL.init(string:)) ?? LinkPreviews.link(in: wish.text) }

    private var title: String {
        if LinkPreviews.isOnlyALink(wish.text), let link { return LinkPreviews.shortName(link) }
        return wish.text
    }

    private var caption: String {
        guard let link else { return wish.savedLine }
        return "\(LinkPreviews.shortName(link)) · \(wish.capturedAt.formatted(.dateTime.month(.abbreviated).day()))"
    }

    @ViewBuilder private var thumbnail: some View {
        if let image = PhotoStore.load(wish.imageFile) {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous))
                .accessibilityHidden(true)
        } else if link != nil {
            RoundedRectangle(cornerRadius: Brand.radiusSm, style: .continuous).fill(Brand.raised)
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: "link").foregroundStyle(Brand.inkMuted))
                .accessibilityHidden(true)
        }
    }
}
