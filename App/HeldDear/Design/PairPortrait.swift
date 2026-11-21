import SwiftUI

/// An anniversary's two faces as overlapping circles (approved Nov 21, 2026). Each circle is framed on its face by
/// FaceFinder; the front one has a thin page-colored edge so the overlap reads on any photo. A missing photo shows
/// initials, so it never looks broken.
struct PairPortrait: View {
    let person: Person
    let partner: PairSide
    var size: CGFloat = 44
    var toned = false
    var fadeBottom = false
    /// Drawn around the front circle (Home's readiness ring).
    var ring: (ready: Int, total: Int)? = nil
    @EnvironmentObject private var model: AppModel
    @State private var partnerImage: UIImage?

    /// How far the circles overlap: about a third.
    private var shift: CGFloat { size * 0.62 }

    var body: some View {
        ZStack {
            back
                .offset(x: -shift / 2)
            front
                .offset(x: shift / 2)
        }
        .frame(width: size + shift + (ring == nil ? 0 : 20), height: size + (ring == nil ? 0 : 20))
        .task(id: partnerKey) { partnerImage = await loadPartner() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    @ViewBuilder private var back: some View {
        ZStack {
            Circle().fill(Brand.raised)
            if let partnerImage {
                Image(uiImage: partnerImage).resizable().scaledToFill()
            } else {
                Text(partnerInitials).font(Brand.display(size * 0.36)).foregroundStyle(Brand.ink)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay { fade }
    }

    @ViewBuilder private var front: some View {
        let portrait = PersonPortrait(person: person, size: size, toned: toned, fadeBottom: fadeBottom)
            .background(Circle().fill(Brand.page).frame(width: size + 6, height: size + 6))
        if let ring {
            ReadyRing(ready: ring.ready, total: ring.total, size: size) { portrait }
        } else {
            portrait
        }
    }

    @ViewBuilder private var fade: some View {
        if fadeBottom {
            Circle().fill(LinearGradient(stops: [
                .init(color: Brand.page.opacity(0), location: 0.45),
                .init(color: Brand.page.opacity(0.7), location: 0.78),
                .init(color: Brand.page, location: 0.98)
            ], startPoint: .top, endPoint: .bottom))
        } else {
            Circle().strokeBorder(Brand.raisedLine, lineWidth: 1)
        }
    }

    private var partnerKey: String {
        switch partner {
        case .person(let id): return id.uuidString
        case .you: return "you-\(YouProfile.photoFile ?? "")"
        case .initials(let s): return s
        }
    }

    private func loadPartner() async -> UIImage? {
        switch partner {
        case .person(let id): return await FaceFinder.shared.portrait(for: model.person(id), side: size, toned: toned)
        case .you: return await FaceFinder.shared.yourPortrait(side: size, toned: toned)
        case .initials: return nil
        }
    }

    private var partnerName: String {
        switch partner {
        case .person(let id): return DisplayName.plain(model.person(id)?.name ?? "")
        case .you: return UserDefaults.standard.string(forKey: "yourName") ?? "You"
        case .initials(let s): return s
        }
    }

    private var partnerInitials: String {
        switch partner {
        case .you:
            let n = UserDefaults.standard.string(forKey: "yourName") ?? ""
            return n.isEmpty ? "You" : AnniversaryPair.initials(n)
        default: return AnniversaryPair.initials(partnerName)
        }
    }

    private var label: String {
        let base = "\(DisplayName.plain(person.name)) and \(partnerName)"
        guard let ring, ring.total > 0 else { return base }
        return base + ", \(ring.ready) of \(ring.total) ready"
    }
}
