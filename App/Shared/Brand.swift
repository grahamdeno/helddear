import SwiftUI
import UIKit

/// Quiet design tokens (v2, decided Nov 12, 2026; replaces Hearth).
/// Ivory and near-black, one family (Instrument Sans for interface, Instrument Serif for names and numbers),
/// square corners, hairline rules, photos large, almost no decoration.
/// Every color has a light and dark value under the same name; never hard-code a light value in a view.
enum Brand {
    // MARK: Color
    static let page = dynamic(0xFAFAF7, 0x111111)
    static let card = dynamic(0xF3F2EE, 0x1B1B1A)
    static let ink = dynamic(0x111111, 0xF2F1EC)
    static let inkMuted = dynamic(0x6A6A66, 0xA3A29C)
    static let line = dynamic(0xE6E5E0, 0x2C2C2A)
    /// Near-black (light) or ivory (dark). The one color for things you tap.
    static let action = dynamic(0x111111, 0xF2F1EC)
    static let onAction = dynamic(0xFAFAF7, 0x111111)
    /// Muted terracotta. Small marks only (a dot, a rule); never body text, never a large fill.
    static let accent = dynamic(0xA3472F, 0xD07A62)
    /// Neutral tint for quiet fills.
    static let accentSoft = dynamic(0xECEAE4, 0x242422)
    static let onAccentSoft = dynamic(0x111111, 0xF2F1EC)
    static let error = dynamic(0xB3261E, 0xF2B8B5)

    /// Neutral face fills behind initials, picked by name so a person keeps their tone.
    static let faceFills: [Color] = [
        dynamic(0xE9E7E1, 0x262624), dynamic(0xE1DED6, 0x2C2B28), dynamic(0xEDEBE6, 0x22221F), dynamic(0xDCD9D1, 0x302F2B),
    ]
    /// Ring fills for the "Your people" rings, outer to inner.
    static let ringOuter = dynamic(0xF3F2EE, 0x1B1B1A)
    static let ringMiddle = dynamic(0xE9E7E1, 0x242422)
    static let ringInner = dynamic(0xDCD9D1, 0x302F2B)

    static func faceFill(for name: String) -> Color {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return faceFills[sum % faceFills.count]
    }

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// The big countdown number (hero and widgets only). Serif, lining figures.
    static func countdownFont(_ size: CGFloat) -> Font {
        TypeStyle.hasInstrument
            ? Font.custom(TypeStyle.serif, size: size, relativeTo: .largeTitle).monospacedDigit()
            : Font.system(size: size, weight: .regular, design: .serif).monospacedDigit()
    }

    /// Serif at an arbitrary size (names on cards, day numbers).
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .body, italic: Bool = false) -> Font {
        guard TypeStyle.hasInstrument else { return Font.system(size: size, design: .serif) }
        return Font.custom(italic ? TypeStyle.serifItalic : TypeStyle.serif, size: size, relativeTo: style)
    }

    // MARK: Spacing and radius
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 22
    static let space6: CGFloat = 32
    /// Square corners. Kept as tokens so views don't hard-code shape.
    static let radiusSm: CGFloat = 2
    static let radiusMd: CGFloat = 2
    static let radiusLg: CGFloat = 2
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Type styles. Instrument Sans and Serif are bundled; each style scales with Dynamic Type.
/// System sans and New York are the fallback.
enum TypeStyle {
    case display, title, headline, body, bodyStrong, callout, caption, eyebrow

    static let serif = "InstrumentSerif-Regular"
    static let serifItalic = "InstrumentSerif-Italic"
    static let sansRegular = "InstrumentSans-Regular"
    static let sansMedium = "InstrumentSans-Medium"
    static let sansSemiBold = "InstrumentSans-SemiBold"
    static let hasInstrument = UIFont(name: "InstrumentSerif-Regular", size: 12) != nil

    var size: CGFloat {
        switch self {
        case .display: 40
        case .title: 32
        case .headline: 24
        case .body, .bodyStrong: 17
        case .callout: 15
        case .caption: 13
        case .eyebrow: 13
        }
    }

    var isSerif: Bool {
        switch self {
        case .display, .title, .headline: true
        default: false
        }
    }

    var fontName: String {
        switch self {
        case .display, .title, .headline: TypeStyle.serif
        case .body, .callout: TypeStyle.sansRegular
        case .bodyStrong: TypeStyle.sansSemiBold
        case .caption, .eyebrow: TypeStyle.sansMedium
        }
    }

    var fallbackWeight: Font.Weight {
        switch self {
        case .bodyStrong: .semibold
        case .caption, .eyebrow: .medium
        default: .regular
        }
    }

    var relative: Font.TextStyle {
        switch self {
        case .display: .largeTitle
        case .title: .title
        case .headline: .title3
        case .body, .bodyStrong: .body
        case .callout: .callout
        case .caption: .caption
        case .eyebrow: .caption2
        }
    }

    /// The same size in SemiBold sans (or the serif for serif styles), for emphasis inside a style.
    var strong: Font {
        if isSerif { return font }
        if TypeStyle.hasInstrument { return Font.custom(TypeStyle.sansSemiBold, size: size, relativeTo: relative) }
        return Font.system(size: size, weight: .semibold)
    }

    var font: Font {
        if TypeStyle.hasInstrument {
            return Font.custom(fontName, size: size, relativeTo: relative)
        }
        return Font.system(size: size, weight: fallbackWeight, design: isSerif ? .serif : .default)
    }
}

extension View {
    func textStyle(_ style: TypeStyle, color: Color = Brand.ink) -> some View {
        self.font(style.font)
            .foregroundStyle(style == .eyebrow && color == Brand.ink ? Brand.inkMuted : color)
            .tracking(style.isSerif ? -0.3 : 0)
    }
}
