import SwiftUI

/// A holiday's own small drawing, in the same circle as a person's face (approved Nov 21, 2026): an evergreen sprig
/// for Christmas, one tulip for Mother's Day, morning coffee for Father's Day. Drawn here in the app's two colors, so
/// it's ours, sharp at any size and right in light and dark. Any other holiday shows its first letter.
struct HolidayMark: View {
    let type: OccasionType
    var name: String? = nil
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(Brand.raised)
            if let drawing = Self.drawing(for: type) {
                Canvas { ctx, canvas in
                    let s = canvas.width / 64
                    for stroke in drawing {
                        let path = stroke.path.applying(CGAffineTransform(scaleX: s, y: s))
                        if stroke.filled { ctx.fill(path, with: .color(stroke.accent ? Brand.action : Brand.ink)) }
                        else {
                            ctx.stroke(path, with: .color(stroke.accent ? Brand.action : Brand.ink),
                                       style: StrokeStyle(lineWidth: max(1, stroke.width * s), lineCap: .round, lineJoin: .round))
                        }
                    }
                }
                .frame(width: size * 0.7, height: size * 0.7)
            } else {
                Text(String((name?.isEmpty == false ? name! : type.label).prefix(1)).uppercased())
                    .font(Brand.display(size * 0.46)).foregroundStyle(Brand.ink)
            }
        }
        .frame(width: size, height: size)
        .overlay { Circle().strokeBorder(Brand.raisedLine, lineWidth: 1) }
        .accessibilityHidden(true)
    }

    struct Stroke {
        var path: Path
        var accent = false
        var filled = false
        var width: CGFloat = 2
    }

    /// The drawings, on a 64-point square.
    static func drawing(for type: OccasionType) -> [Stroke]? {
        switch type {
        case .christmas:
            var branches = Path()
            branches.move(to: CGPoint(x: 32, y: 54)); branches.addLine(to: CGPoint(x: 32, y: 12))
            for (y, w) in [(46.0, 14.0), (38, 12), (30, 10), (22, 7)] {
                branches.move(to: CGPoint(x: 32, y: y)); branches.addLine(to: CGPoint(x: 32 - w, y: y - 6))
                branches.move(to: CGPoint(x: 32, y: y)); branches.addLine(to: CGPoint(x: 32 + w, y: y - 6))
            }
            var berries = Path()
            for (x, y, r) in [(21.0, 44.0, 2.6), (43, 36, 2.6), (25, 27, 2.2)] {
                berries.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            return [Stroke(path: branches), Stroke(path: berries, accent: true, filled: true)]
        case .mothersDay:
            var stem = Path()
            stem.move(to: CGPoint(x: 32, y: 56)); stem.addLine(to: CGPoint(x: 32, y: 32))
            stem.move(to: CGPoint(x: 32, y: 48))
            stem.addCurve(to: CGPoint(x: 21, y: 34), control1: CGPoint(x: 26, y: 46), control2: CGPoint(x: 22, y: 40))
            stem.addCurve(to: CGPoint(x: 32, y: 46), control1: CGPoint(x: 27, y: 36), control2: CGPoint(x: 31, y: 41))
            var flower = Path()
            flower.move(to: CGPoint(x: 22, y: 14))
            flower.addLine(to: CGPoint(x: 27, y: 19)); flower.addLine(to: CGPoint(x: 32, y: 12))
            flower.addLine(to: CGPoint(x: 37, y: 19)); flower.addLine(to: CGPoint(x: 42, y: 14))
            flower.addCurve(to: CGPoint(x: 32, y: 32), control1: CGPoint(x: 44, y: 24), control2: CGPoint(x: 40, y: 32))
            flower.addCurve(to: CGPoint(x: 22, y: 14), control1: CGPoint(x: 24, y: 32), control2: CGPoint(x: 20, y: 24))
            flower.closeSubpath()
            return [Stroke(path: stem), Stroke(path: flower, accent: true, width: 2.2)]
        case .fathersDay:
            var cup = Path()
            cup.move(to: CGPoint(x: 18, y: 30)); cup.addLine(to: CGPoint(x: 42, y: 30)); cup.addLine(to: CGPoint(x: 42, y: 44))
            cup.addCurve(to: CGPoint(x: 30, y: 54), control1: CGPoint(x: 42, y: 50), control2: CGPoint(x: 37, y: 54))
            cup.addCurve(to: CGPoint(x: 18, y: 44), control1: CGPoint(x: 23, y: 54), control2: CGPoint(x: 18, y: 50))
            cup.closeSubpath()
            cup.move(to: CGPoint(x: 42, y: 34)); cup.addLine(to: CGPoint(x: 46, y: 34))
            cup.addCurve(to: CGPoint(x: 46, y: 44), control1: CGPoint(x: 50, y: 34), control2: CGPoint(x: 50, y: 44))
            cup.addLine(to: CGPoint(x: 42, y: 44))
            var steam = Path()
            for x in [25.0, 32, 39] {
                steam.move(to: CGPoint(x: x, y: 24))
                steam.addCurve(to: CGPoint(x: x, y: 13), control1: CGPoint(x: x - 2, y: 20), control2: CGPoint(x: x + 2, y: 18))
            }
            return [Stroke(path: cup), Stroke(path: steam, accent: true)]
        default:
            return nil
        }
    }
}
