import Photos
import SwiftUI

/// The top of a person's page (approved Nov 20, 2026): their photo fills the top and fades into the page, with the
/// name large over the fade. Slide sideways to step back through past birthdays: each shows a photo from that day
/// in the library on this iPhone and that year's one line. Free shows this year and the most recent past year;
/// Lifetime shows every year (the same rule as before).
struct PersonHero: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var photos = PhotoMemories.shared
    @ObservedObject private var purchases = Purchases.shared
    let person: Person
    let line: String
    let tag: String?

    @State private var page = 0
    @State private var years: [PhotoMemories.Year] = []

    static let height: CGFloat = 460

    private struct Page: Identifiable {
        let id: Int
        let year: Int?
        let asset: PHAsset?
        let caption: String
    }

    private var pages: [Page] {
        var result = [Page(id: 0, year: nil, asset: nil, caption: line)]
        let past = purchases.hasLifetime ? years : Array(years.prefix(1))
        for y in past {
            let entry = person.sortedLedger.first { $0.year == y.year }
            let words = entry.map { ($0.line?.isEmpty == false ? $0.line! : $0.what) }
            let caption = words.map { "\(y.year) · \($0)" } ?? String(y.year)
            result.append(Page(id: y.year, year: y.year, asset: y.assets.first, caption: caption))
        }
        return result
    }

    var body: some View {
        let pages = self.pages
        let current = pages.indices.contains(page) ? pages[page] : pages[0]
        ZStack(alignment: .bottomLeading) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { i, p in
                    photo(p).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: Self.height)
            .overlay {
                LinearGradient(stops: [
                    .init(color: Color.black.opacity(0.35), location: 0),
                    .init(color: .clear, location: 0.22),
                    .init(color: .clear, location: 0.5),
                    .init(color: Brand.page.opacity(0.85), location: 0.8),
                    .init(color: Brand.page, location: 1),
                ], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Brand.space2) {
                Text(DisplayName.plain(person.name))
                    .font(Brand.display(NameSize.featured(DisplayName.plain(person.name)), relativeTo: .largeTitle)).tracking(-2)
                    .foregroundStyle(Brand.ink)
                    .lineLimit(NameSize.maxLines).minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                Text(current.caption)
                    .font(Brand.display(20, relativeTo: .title3, italic: true)).foregroundStyle(Brand.inkSoft)
                    .lineLimit(2)
                    .accessibilityLabel(page == 0 ? current.caption : "Photo from \(current.caption)")
                if pages.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(pages.indices, id: \.self) { i in
                            Capsule().fill(i == page ? Brand.action : Brand.inkMuted.opacity(0.5))
                                .frame(width: i == page ? 22 : 8, height: 8)
                        }
                        Text(page == 0 ? "Slide for past years" : "")
                            .textStyle(.caption, color: Brand.inkMuted)
                            .padding(.leading, 4)
                    }
                    .padding(.top, Brand.space1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Year \(page + 1) of \(pages.count)")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: page = min(page + 1, pages.count - 1)
                        case .decrement: page = max(page - 1, 0)
                        @unknown default: break
                        }
                    }
                }
            }
            .padding(.horizontal, Brand.space5)
            .padding(.bottom, Brand.space4)
            .animation(.easeOut(duration: 0.2), value: page)
        }
        .overlay(alignment: .topTrailing) {
            if let tag {
                Text(tag).font(.footnote.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.black.opacity(0.35), in: Capsule())
                    .padding(.top, 60).padding(.trailing, Brand.space4)
                    .accessibilityHidden(true)
            }
        }
        .onAppear(perform: load)
    }

    @ViewBuilder private func photo(_ p: Page) -> some View {
        if let asset = p.asset {
            HeroAsset(asset: asset)
        } else {
            let image = PhotoStore.load(person.photoFiles.last) ?? ContactsService.shared.photo(contactID: person.contactID)
            ZStack {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Brand.faceFill(for: person.name)
                    Text(person.initials).font(Brand.display(140)).foregroundStyle(Brand.ink.opacity(0.35))
                        .padding(.bottom, 120)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .clipped()
        }
    }

    private func load() {
        guard photos.canRead, let b = person.birthday else { return }
        let thisYear = Calendar.current.component(.year, from: Date())
        years = photos.years(month: b.month, day: b.day).filter { $0.year < thisYear && !$0.assets.isEmpty }
            .sorted { $0.year > $1.year }
    }
}

/// One past year's photo, loaded at screen size.
private struct HeroAsset: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Brand.card
            if let image { Image(uiImage: image).resizable().scaledToFill() }
        }
        .frame(maxWidth: .infinity)
        .frame(height: PersonHero.height)
        .clipped()
        .task(id: asset.localIdentifier) { image = await PhotoMemories.shared.thumbnail(asset, side: 1000) }
    }
}
