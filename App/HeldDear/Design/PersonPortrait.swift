import SwiftUI

/// A person's face in a small circle (approved Nov 21, 2026): framed on their face by FaceFinder, or their initial
/// when there's no photo. Circles mean people; rounded squares mean things.
struct PersonPortrait: View {
    let person: Person?
    var size: CGFloat = 44
    /// Warm two-tone photo (Home's medallion).
    var toned = false
    /// The bottom fades into the page, like the photo on a person's page (Home's medallion).
    var fadeBottom = false
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
        .overlay {
            if fadeBottom {
                Circle().fill(LinearGradient(stops: [
                    .init(color: Brand.page.opacity(0), location: 0.3),
                    .init(color: Brand.page.opacity(0.7), location: 0.7),
                    .init(color: Brand.page, location: 0.96)
                ], startPoint: .top, endPoint: .bottom))
            } else {
                Circle().strokeBorder(Brand.raisedLine, lineWidth: 1)
            }
        }
        .task(id: person?.id) { image = await FaceFinder.shared.portrait(for: person, side: size, toned: toned) }
        .accessibilityHidden(true)
    }

    private var initial: String {
        String(DisplayName.plain(person?.name ?? "").prefix(1)).uppercased()
    }
}
