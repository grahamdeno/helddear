import SwiftUI
import UIKit

// Components the app, the share extension and the widget all draw.

struct Tag: View {
    var text: String
    var body: some View {
        Text(text).font(TypeStyle.caption.font)
            .foregroundStyle(Brand.ink)
            .padding(.vertical, 5).padding(.horizontal, 10)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

/// A person's face: their contact photo, or initials in serif on a warm fill.
struct Face: View {
    var name: String
    var initials: String
    var image: UIImage?
    var size: CGFloat = 44
    var fill: Color?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(initials).font(Brand.serif(size * 0.42))
                    .foregroundStyle(Brand.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(fill ?? Brand.faceFill(for: name))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(4, size * 0.12), style: .continuous))
        .accessibilityHidden(true)
    }
}

