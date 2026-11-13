import SwiftUI
import UIKit

/// Birthday card designs. Portrait 5:7, drawn at 500 x 700 points and rendered at 3x = 1500 x 2100 px,
/// a true 5x7 at 300 dpi, so mailed cards can print from the same art. Colors are fixed (not light/dark),
/// because a card is an object, not a screen. Every design works without a photo.
enum CardDesign: String, CaseIterable, Identifiable {
    case hearth, postmark, circles, snapshot, bigNumber, evening

    var id: String { rawValue }

    var name: String {
        switch self {
        case .hearth: "Hearth"
        case .postmark: "Postmark"
        case .circles: "Circles"
        case .snapshot: "Snapshot"
        case .bigNumber: "Big Number"
        case .evening: "Evening"
        }
    }

    /// Hearth is free; the rest come with Held Dear Lifetime.
    var isFree: Bool { self == .hearth }
}

struct CardContent {
    var name: String
    var photo: UIImage?
    /// The user's own words (Lifetime). Nil means the standard "Happy birthday," + name.
    var words: String?
    /// Shown only when the user turned age on for this person.
    var age: Int?
    var date: Date
    var occasion: OccasionType = .birthday

    /// "Turning 70", "40 years", or nil.
    var countText: String? {
        guard let age else { return nil }
        return occasion == .birthday ? "Turning \(age)" : "\(age) years"
    }

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

enum CardPalette {
    static let cream = Color(red: 1, green: 0.957, blue: 0.925)          // #FFF4EC
    static let ink = Color(red: 0.227, green: 0.137, blue: 0.251)        // #3A2340
    static let plum = Color(red: 0.357, green: 0.165, blue: 0.369)       // #5B2A5E
    static let deepPlum = Color(red: 0.165, green: 0.082, blue: 0.188)   // #2A1530
    static let coral = Color(red: 0.910, green: 0.404, blue: 0.290)      // #E8674A
    static let apricot = Color(red: 0.965, green: 0.706, blue: 0.561)    // #F6B48F
    static let blush = Color(red: 0.953, green: 0.851, blue: 0.784)      // #F3D9C8
}

/// Card type: names and numbers in Instrument Serif, small lines in Instrument Sans.
func cardFont(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
    if weight == .heavy { return Brand.serif(size) }
    return TypeStyle.hasInstrument ? Font.custom(TypeStyle.sansMedium, size: size) : Font.system(size: size, weight: .medium)
}

struct CardView: View {
    var design: CardDesign
    var content: CardContent

    static let size = CGSize(width: 500, height: 700)

    var body: some View {
        Group {
            switch design {
            case .hearth: hearth
            case .postmark: postmark
            case .circles: circles
            case .snapshot: snapshot
            case .bigNumber: bigNumber
            case .evening: evening
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
    }

    // MARK: Shared pieces

    @ViewBuilder private func greeting(color: Color, nameColor: Color, nameSize: CGFloat = 54) -> some View {
        VStack(spacing: 4) {
            if let words = content.words, !words.isEmpty {
                Text(words).font(cardFont(nameSize * 0.7)).foregroundStyle(nameColor)
                    .multilineTextAlignment(.center).minimumScaleFactor(0.5).lineLimit(3)
            } else {
                Text(content.occasion.cardOpening).font(cardFont(28)).foregroundStyle(color)
                Text(content.name).font(cardFont(nameSize)).foregroundStyle(nameColor)
                    .minimumScaleFactor(0.4).lineLimit(1)
            }
            if let count = content.countText {
                Text(count).font(cardFont(20, .bold)).foregroundStyle(color.opacity(0.8)).padding(.top, 2)
            }
        }
        .padding(.horizontal, 30)
    }

    private func photoOrFill(_ fill: Color, initialsColor: Color = CardPalette.ink) -> some View {
        ZStack {
            if let photo = content.photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                fill
                Text(content.initials).font(cardFont(120)).foregroundStyle(initialsColor)
            }
        }
    }

    private var mark: some View {
        ZStack {
            Circle().fill(CardPalette.apricot).frame(width: 16, height: 16).offset(y: -5)
            Circle().fill(CardPalette.coral).frame(width: 16, height: 16).offset(x: -6, y: 5)
            Circle().fill(CardPalette.plum).frame(width: 16, height: 16).offset(x: 6, y: 5)
        }
        .compositingGroup()
        .opacity(0.9)
    }

    private var bigCircles: some View {
        ZStack {
            Circle().fill(CardPalette.apricot).frame(width: 220, height: 220).offset(y: -70)
            Circle().fill(CardPalette.coral).frame(width: 220, height: 220).offset(x: -80, y: 60).blendMode(.multiply)
            Circle().fill(CardPalette.plum.opacity(0.9)).frame(width: 220, height: 220).offset(x: 80, y: 60).blendMode(.multiply)
        }
        .compositingGroup()
    }

    // MARK: Hearth (free)

    private var hearth: some View {
        ZStack {
            CardPalette.cream
            VStack(spacing: 0) {
                Group {
                    if content.photo != nil {
                        photoOrFill(CardPalette.blush)
                    } else {
                        ZStack { CardPalette.cream; bigCircles }
                    }
                }
                .frame(width: 440, height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.top, 30)
                Spacer(minLength: 0)
                greeting(color: CardPalette.ink, nameColor: CardPalette.plum)
                Spacer(minLength: 0)
                mark.padding(.bottom, 26)
            }
        }
    }

    // MARK: Postmark

    private var postmark: some View {
        let date = content.date.formatted(.dateTime.month(.abbreviated).day().year()).uppercased()
        return ZStack {
            CardPalette.cream
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    photoOrFill(CardPalette.blush)
                        .frame(width: 300, height: 360)
                        .clipped()
                        .padding(14)
                        .background(Color.white)
                        .overlay(Rectangle().strokeBorder(CardPalette.cream, style: StrokeStyle(lineWidth: 10, dash: [2, 12])))
                        .rotationEffect(.degrees(3))
                    ZStack {
                        Circle().stroke(CardPalette.plum.opacity(0.75), lineWidth: 4).frame(width: 130, height: 130)
                        Circle().stroke(CardPalette.plum.opacity(0.75), lineWidth: 2).frame(width: 108, height: 108)
                        Text(date).font(cardFont(17)).foregroundStyle(CardPalette.plum.opacity(0.85))
                            .multilineTextAlignment(.center).frame(width: 96)
                    }
                    .rotationEffect(.degrees(-12))
                    .offset(x: 50, y: -30)
                }
                .padding(.top, 70)
                Spacer(minLength: 0)
                greeting(color: CardPalette.ink, nameColor: CardPalette.plum)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: Circles

    private var circles: some View {
        ZStack {
            CardPalette.cream
            Circle().fill(CardPalette.apricot).frame(width: 520, height: 520).offset(x: -170, y: -260)
            Circle().fill(CardPalette.coral).frame(width: 360, height: 360).offset(x: 190, y: -300).blendMode(.multiply)
            photoOrFill(CardPalette.plum, initialsColor: CardPalette.cream)
                .frame(width: 330, height: 330)
                .clipShape(Circle())
                .overlay(Circle().stroke(CardPalette.plum, lineWidth: 10))
                .offset(y: -90)
            VStack {
                Spacer()
                greeting(color: CardPalette.ink, nameColor: CardPalette.plum, nameSize: 50)
                    .padding(.bottom, 54)
            }
        }
        .compositingGroup()
    }

    // MARK: Snapshot

    private var snapshot: some View {
        ZStack {
            CardPalette.cream
            VStack(spacing: 18) {
                photoOrFill(CardPalette.apricot)
                    .frame(width: 360, height: 380)
                    .clipped()
                Group {
                    if let words = content.words, !words.isEmpty {
                        Text(words)
                    } else {
                        Text("\(content.occasion.cardOpening) \(content.name)")
                    }
                }
                .font(cardFont(30)).foregroundStyle(CardPalette.ink)
                .multilineTextAlignment(.center).minimumScaleFactor(0.5).lineLimit(2)
                .frame(width: 360)
                if let count = content.countText {
                    Text(count).font(cardFont(18, .bold)).foregroundStyle(CardPalette.ink.opacity(0.7))
                }
            }
            .padding(.top, 22).padding(.horizontal, 22).padding(.bottom, 44)
            .background(Color.white)
            .rotationEffect(.degrees(-2))
        }
    }

    // MARK: Big Number

    private var bigNumber: some View {
        let number = content.age.map(String.init) ?? String(Calendar.current.component(.day, from: content.date))
        let numeral = Text(number).font(cardFont(number.count > 2 ? 240 : 330)).minimumScaleFactor(0.5).lineLimit(1)
        return ZStack {
            CardPalette.cream
            VStack(spacing: 6) {
                Group {
                    if let photo = content.photo {
                        Image(uiImage: photo).resizable().scaledToFill()
                            .frame(width: 460, height: 400)
                            .clipped()
                            .mask(numeral.frame(width: 460, height: 400))
                    } else {
                        numeral.foregroundStyle(CardPalette.plum).frame(width: 460, height: 400)
                    }
                }
                .padding(.top, 40)
                Spacer(minLength: 0)
                Group {
                    if let words = content.words, !words.isEmpty {
                        Text(words)
                    } else {
                        Text("\(content.occasion.cardOpening) \(content.name)")
                    }
                }
                .font(cardFont(32)).foregroundStyle(CardPalette.ink)
                .multilineTextAlignment(.center).minimumScaleFactor(0.5).lineLimit(2)
                .padding(.horizontal, 30)
                Text(content.age == nil ? content.date.formatted(.dateTime.month(.wide)) : "years")
                    .font(cardFont(18, .bold)).foregroundStyle(CardPalette.ink.opacity(0.65))
                Spacer(minLength: 0)
                mark.padding(.bottom, 26)
            }
        }
    }

    // MARK: Evening

    private var evening: some View {
        ZStack {
            CardPalette.deepPlum
            ForEach(0..<14, id: \.self) { i in
                Circle().fill(CardPalette.cream.opacity(i % 3 == 0 ? 0.55 : 0.3))
                    .frame(width: i % 4 == 0 ? 5 : 3, height: i % 4 == 0 ? 5 : 3)
                    .offset(x: CGFloat((i * 97) % 440) - 220, y: CGFloat((i * 53) % 300) - 320)
            }
            VStack(spacing: 0) {
                photoOrFill(CardPalette.apricot, initialsColor: CardPalette.deepPlum)
                    .frame(width: 300, height: 300)
                    .clipShape(Circle())
                    .padding(.top, 90)
                Spacer(minLength: 0)
                greeting(color: CardPalette.cream.opacity(0.85), nameColor: CardPalette.cream)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 40)
        }
    }
}

/// Renders a card to a 1500 x 2100 image on the phone.
enum CardRenderer {
    @MainActor
    static func image(design: CardDesign, content: CardContent) -> UIImage? {
        let renderer = ImageRenderer(content: CardView(design: design, content: content).environment(\.colorScheme, .light))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
