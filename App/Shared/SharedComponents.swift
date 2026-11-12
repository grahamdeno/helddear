import SwiftUI
import UIKit

// Components the app, the share extension and the widget all draw.

struct Tag: View {
    var text: String
    var body: some View {
        Text(text).font(TypeStyle.caption.font.weight(.heavy))
            .foregroundStyle(Brand.onAccentSoft)
            .padding(.vertical, 4).padding(.horizontal, 12)
            .background(Brand.accentSoft, in: Capsule())
    }
}

/// A person's face: their contact photo, or initials on a soft fill.
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
                Text(initials).font(.system(size: size * 0.36, weight: .heavy, design: .rounded))
                    .foregroundStyle(Brand.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(fill ?? Brand.faceFill(for: name))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

