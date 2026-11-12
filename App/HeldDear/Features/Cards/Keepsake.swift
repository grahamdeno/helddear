import SwiftUI
import UIKit

/// The yearly keepsake (Lifetime): one person, one year, rendered on the phone to share.
enum Keepsake {
    @MainActor
    static func image(person: Person, entry: LedgerEntry) -> UIImage? {
        let view = KeepsakeView(name: person.name, year: entry.year, what: entry.what, line: entry.line,
                                photo: PhotoStore.load(entry.cardFile ?? entry.photoFile))
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.uiImage
    }
}

struct KeepsakeView: View {
    var name: String
    var year: Int
    var what: String
    var line: String?
    var photo: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(name.uppercased()) · \(String(year))").font(cardFont(16)).tracking(2).foregroundStyle(CardPalette.ink.opacity(0.7))
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
                    .frame(width: 340, height: 340).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            Text(what).font(cardFont(26)).foregroundStyle(CardPalette.ink)
            if let line { Text("“\(line)”").font(cardFont(22, .semibold)).foregroundStyle(CardPalette.plum) }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                CirclesMark(size: 22)
                Text("Held Dear").font(cardFont(14, .bold)).foregroundStyle(CardPalette.ink.opacity(0.6))
            }
        }
        .padding(30)
        .frame(width: 400, height: 560, alignment: .topLeading)
        .background(CardPalette.cream)
    }
}
