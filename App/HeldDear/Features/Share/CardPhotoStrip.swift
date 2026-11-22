import PhotosUI
import SwiftUI

/// The row of photos above a card's preview, the same on the share card and the digital card (Nov 22, 2026): small
/// squares, the chosen one outlined in the action color, and an optional square at the end to pick from the library.
struct CardPhotoStrip: View {
    var count: Int
    var selected: Int?
    var thumb: (Int) -> UIImage?
    var onSelect: (Int) -> Void
    /// Set to offer "Library" at the end of the row.
    var library: Binding<PhotosPickerItem?>? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Brand.space2) {
                ForEach(0..<count, id: \.self) { i in
                    Button { onSelect(i) } label: {
                        Group {
                            if let image = thumb(i) {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                Brand.card
                            }
                        }
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(i == selected ? Brand.action : Color.clear, lineWidth: 2)
                        }
                        .frame(width: 56, height: 56)
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Photo \(i + 1)")
                    .accessibilityAddTraits(i == selected ? [.isButton, .isSelected] : .isButton)
                }
                if let library {
                    PhotosPicker(selection: library, matching: .images) {
                        VStack(spacing: 2) {
                            Image(systemName: "photo.on.rectangle").font(.system(size: 16))
                            Text("Library").font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(Brand.action)
                        .frame(width: 52, height: 52)
                        .background(Brand.card, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .frame(width: 56, height: 56)
                    }
                    .accessibilityLabel("Choose a photo from your library")
                }
            }
        }
    }
}

/// The drag that places the photo, laid over the photo part of a card's preview. Same on both cards.
struct CardPhotoDrag: View {
    var width: CGFloat
    var height: CGFloat
    var onChanged: (CGSize) -> Void
    var onEnded: () -> Void

    var body: some View {
        Color.clear
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance: 2)
                .onChanged { onChanged($0.translation) }
                .onEnded { _ in onEnded() })
            .accessibilityLabel("Photo")
            .accessibilityHint("Drag to place the photo")
    }
}
