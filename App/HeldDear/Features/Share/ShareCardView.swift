import SwiftUI

/// What a share image shows. Built by ShareDayFlow from a person's day.
struct ShareCardContent {
    var name: String
    var subline: String
    var date: Date
    var note: String
    /// One photo for a still card; several play as a slideshow first in the moving version (Nov 22, 2026). The first
    /// is the still card's photo.
    var photos: [UIImage] = []
    /// The user's name under the line, as on the digital card ("Love, Graham"). Empty leaves it off.
    var signature: String = ""

    var photo: UIImage? { photos.first }
}

/// The share image (approved Nov 21, 2026): the photo across the top fading into the page, the name large, one
/// line, and Home's timeline with an oxblood dot on the day. `time` runs the moving version (0 to
/// ShareCardLayout.duration); the still image is the last moment. Laid out on a 390-point-wide canvas and rendered
/// larger, always in the dark stone colors so it looks the same wherever it's posted.
struct ShareCardView: View {
    enum Shape { case post, story
        var height: CGFloat { self == .post ? 488 : 693 }
        var aspect: CGFloat { 390 / photoHeight }
        var photoHeight: CGFloat { self == .post ? 290 : 470 }
    }

    let content: ShareCardContent
    let shape: Shape
    /// The moment shown. nil is the still card (the last moment, with the first photo).
    var time: Double? = nil

    private let width: CGFloat = 390
    private let ink = Color(red: 0.937, green: 0.910, blue: 0.863)
    private let soft = Color(red: 0.812, green: 0.776, blue: 0.722)
    private let muted = Color(red: 0.561, green: 0.525, blue: 0.478)
    private let page = Color(red: 0.090, green: 0.082, blue: 0.075)
    private let accent = Color(red: 0.851, green: 0.541, blue: 0.494)

    private struct Spots { var name, sub, note, line: CGFloat }
    private var spots: Spots {
        shape == .post ? Spots(name: 226, sub: 312, note: 348, line: 432) : Spots(name: 396, sub: 486, note: 612, line: 560)
    }

    /// The slideshow runs first; everything else starts after it, on the same timing as before.
    private var lead: Double { ShareCardLayout.lead(photos: content.photos.count) }

    var body: some View {
        let t = time.map { $0 - lead } ?? ShareCardLayout.duration
        let r = ShareCardLayout.ramp
        ZStack(alignment: .topLeading) {
            page
            photo(t)
            // The name, its line and the note rise in after the dot lands.
            Text(content.name)
                .font(Brand.display(84, relativeTo: .largeTitle)).tracking(-1.5).foregroundStyle(ink)
                .lineLimit(1).minimumScaleFactor(0.45)
                .frame(width: width - 40, height: 90)
                .position(x: width / 2, y: spots.name + 45)
                .opacity(r(t, 3.0, 3.65)).offset(y: 14 * (1 - r(t, 3.0, 3.65)))
            Text(content.subline)
                .font(Brand.display(21, relativeTo: .title3, italic: true)).foregroundStyle(soft)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: width - 48)
                .position(x: width / 2, y: spots.sub + 14)
                .opacity(r(t, 3.75, 4.4)).offset(y: 10 * (1 - r(t, 3.75, 4.4)))
            if !content.note.isEmpty || !content.signature.isEmpty {
                // The ending, as on the digital card: the line, then the user's name.
                VStack(spacing: 6) {
                    if !content.note.isEmpty {
                        Text(content.note)
                            .font(Brand.display(17, relativeTo: .body, italic: true)).foregroundStyle(soft)
                            .multilineTextAlignment(.center)
                            .lineLimit(shape == .post && !content.signature.isEmpty ? 1 : 2).minimumScaleFactor(0.7)
                            .opacity(r(t, 4.3, 4.95))
                    }
                    if !content.signature.isEmpty {
                        Text(content.signature).font(.system(size: 13, weight: .medium)).tracking(0.6).foregroundStyle(muted)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .opacity(r(t, 4.7, 5.35))
                    }
                }
                .frame(width: width - 60)
                .position(x: width / 2, y: spots.note + (content.signature.isEmpty || content.note.isEmpty ? 12 : 20))
            }
            timeline(t)
            Text("HELD DEAR").font(.system(size: 10, weight: .regular)).tracking(1.6).foregroundStyle(muted.opacity(0.8))
                .frame(width: width)
                .position(x: width / 2, y: shape.height - 18)
        }
        .frame(width: width, height: shape.height)
        .clipped()
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private func photo(_ t: Double) -> some View {
        let r = ShareCardLayout.ramp
        let n = content.photos.count
        ZStack {
            if n > 1, let raw = time {
                // The slideshow, on the digital card's beat; the last photo stays bright under the line and the words.
                let slide = GreetingCard.slide(at: min(raw, lead + 0.5), photos: n)
                if slide.index > 0 { image(content.photos[slide.index - 1], zoom: 1) }
                image(content.photos[slide.index],
                      zoom: 1.04 - 0.04 * min(1, max(0, raw - Double(slide.index) * GreetingCard.perPhoto) / GreetingCard.perPhoto))
                    .opacity(slide.fade)
            } else if let photo = content.photo {
                let bright = n > 1 ? 1 : r(t, 2.6, 3.9)
                image(photo, zoom: 1.06 - 0.06 * bright).opacity(0.25 + 0.75 * bright)
            }
            LinearGradient(stops: [
                .init(color: page.opacity(0.25), location: 0), .init(color: page.opacity(0), location: 0.2),
                .init(color: page.opacity(0), location: 0.52), .init(color: page.opacity(0.85), location: 0.84),
                .init(color: page, location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
        .frame(width: width, height: shape.photoHeight)
    }

    private func image(_ photo: UIImage, zoom: Double) -> some View {
        Image(uiImage: photo).resizable().scaledToFill()
            .frame(width: width, height: shape.photoHeight)
            .scaleEffect(zoom)
            .clipped()
    }

    @ViewBuilder private func timeline(_ t: Double) -> some View {
        let r = ShareCardLayout.ramp
        let left: CGFloat = 20, right: CGFloat = 370
        let step = (right - left) / 7
        let months = ShareCardLayout.months(around: content.date)
        let dotX = left + (right - left) * ShareCardLayout.position(of: content.date)
        let y = spots.line
        let travel = r(t, 0.9, 2.6)
        let x = left + (dotX - left) * travel
        let pulse = 1 + 0.5 * max(0, 1 - abs(t - 2.85) / 0.25)

        Rectangle().fill(ink).frame(width: width * r(t, 0, 1.95), height: 1.5)
            .position(x: width * r(t, 0, 1.95) / 2, y: y)
        ForEach(Array(months.enumerated()), id: \.offset) { i, m in
            let shown = r(t, 0.25 + Double(i) * 0.12, 0.75 + Double(i) * 0.12)
            Rectangle().fill(ink).frame(width: 1.5, height: 8)
                .position(x: left + step * CGFloat(i), y: y - 4).opacity(shown)
            Text(m.formatted(.dateTime.month(.abbreviated))).font(.system(size: 11)).foregroundStyle(muted)
                .fixedSize()
                .position(x: left + step * CGFloat(i) + 12, y: y + 20).opacity(shown)
        }
        Rectangle().fill(accent).frame(width: 1.5, height: 40 * r(t, 2.75, 3.25))
            .position(x: dotX, y: y - 20 * r(t, 2.75, 3.25))
        Text(ShareCardLayout.dotLabel(content.date))
            .font(Brand.display(19, relativeTo: .title3)).foregroundStyle(accent).fixedSize()
            .position(x: dotX - 40, y: y - 34)
            .opacity(r(t, 3.0, 3.65))
        // The dot lands exactly under its line, which rises from the dot's center (Graham, Nov 21, 2026).
        Circle().fill(accent).frame(width: 12, height: 12).scaleEffect(pulse)
            .position(x: x, y: y)
            .opacity(r(t, 0.65, 0.9))
    }
}
