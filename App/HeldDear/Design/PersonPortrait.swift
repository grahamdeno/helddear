import SwiftUI

/// A person's face in a small circle (approved Nov 21, 2026): framed on their face by FaceFinder, or their initial
/// when there's no photo. Circles mean people; rounded squares mean things.
struct PersonPortrait: View {
    let person: Person?
    var size: CGFloat = 44
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(Brand.raised)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(initial).font(Brand.display(size * 0.46)).foregroundStyle(Brand.ink)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(Brand.raisedLine, lineWidth: 1) }
        .task(id: person?.id) { image = await FaceFinder.shared.portrait(for: person, side: size) }
        .accessibilityHidden(true)
    }

    private var initial: String {
        String(DisplayName.plain(person?.name ?? "").prefix(1)).uppercased()
    }
}
