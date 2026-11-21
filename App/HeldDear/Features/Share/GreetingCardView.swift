import SwiftUI

struct GreetingCardContent {
    var heading: String
    var line: String
    var signature: String
    var photos: [UIImage]
    var mark: OccasionType?
}

/// A digital card from the user (story 2.11): the photos across the top (one, or a series that crossfades in the
/// moving version), the holiday's mark where the photo fades, the heading large, the user's line and their name.
/// Same dark stone colors as the share image, laid out 390 points wide. `time` nil is the still card.
struct GreetingCardView: View {
    let content: GreetingCardContent
    let shape: ShareCardView.Shape
    var time: Double? = nil

    private let width: CGFloat = 390
    private let ink = Color(red: 0.937, green: 0.910, blue: 0.863)
    private let soft = Color(red: 0.812, green: 0.776, blue: 0.722)
    private let muted = Color(red: 0.561, green: 0.525, blue: 0.478)
    private let page = Color(red: 0.090, green: 0.082, blue: 0.075)

    private var photoHeight: CGFloat { shape.photoHeight }
    private var headingY: CGFloat { shape == .post ? photoHeight + 20 : photoHeight + 30 }

    var body: some View {
        let words = wordsShown
        ZStack(alignment: .topLeading) {
            page
            photos
            if let mark = content.mark {
                HolidayMark(type: mark, size: 52)
                    .position(x: width / 2, y: photoHeight - 6)
                    .opacity(words.heading)
            }
            Text(content.heading)
                .font(Brand.display(shape == .post ? 46 : 54, relativeTo: .largeTitle)).tracking(-0.8).foregroundStyle(ink)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.5)
                .frame(width: width - 40, height: shape == .post ? 110 : 130)
                .position(x: width / 2, y: headingY + (shape == .post ? 55 : 65))
                .opacity(words.heading).offset(y: 14 * (1 - words.heading))
            VStack(spacing: 8) {
                if !content.line.isEmpty {
                    Text(content.line)
                        .font(Brand.display(18, relativeTo: .body, italic: true)).foregroundStyle(soft)
                        .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.7)
                }
                if !content.signature.isEmpty {
                    Text(content.signature).font(.system(size: 13, weight: .medium)).tracking(0.6).foregroundStyle(muted)
                }
            }
            .frame(width: width - 60)
            .position(x: width / 2, y: headingY + (shape == .post ? 140 : 180))
            .opacity(words.rest)
            Text("HELD DEAR").font(.system(size: 10)).tracking(1.6).foregroundStyle(muted.opacity(0.8))
                .frame(width: width)
                .position(x: width / 2, y: shape.height - 18)
        }
        .frame(width: width, height: shape.height)
        .clipped()
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .dark)
    }

    private var wordsShown: (heading: Double, rest: Double) {
        guard let t = time else { return (1, 1) }
        let start = GreetingCard.wordsStart(photos: content.photos.count)
        return (ShareCardLayout.ramp(t, from: start, to: start + 0.7), ShareCardLayout.ramp(t, from: start + 0.7, to: start + 1.4))
    }

    @ViewBuilder private var photos: some View {
        ZStack {
            if content.photos.isEmpty {
                page
            } else if let t = time {
                let slide = GreetingCard.slide(at: t, photos: content.photos.count)
                if slide.index > 0 { photo(content.photos[slide.index - 1], zoom: 1) }
                photo(content.photos[slide.index], zoom: 1.04 - 0.04 * min(1, (t - Double(slide.index) * GreetingCard.perPhoto) / GreetingCard.perPhoto))
                    .opacity(slide.fade)
            } else {
                photo(content.photos[0], zoom: 1)
            }
            LinearGradient(stops: [
                .init(color: page.opacity(0.2), location: 0), .init(color: page.opacity(0), location: 0.2),
                .init(color: page.opacity(0), location: 0.55), .init(color: page.opacity(0.85), location: 0.86),
                .init(color: page, location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
        .frame(width: width, height: photoHeight)
        .clipped()
    }

    private func photo(_ image: UIImage, zoom: Double) -> some View {
        Image(uiImage: image).resizable().scaledToFill()
            .frame(width: width, height: photoHeight)
            .scaleEffect(zoom)
            .clipped()
    }
}
