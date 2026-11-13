import SwiftUI
import UIKit

/// Horizon design tokens (v3, chosen Nov 12, 2026; replaces Quiet).
/// Warm stone pages, one composed screen at a time, the person's name very large in a light serif (Fraunces),
/// interface text in the system sans, one oxblood action per screen, time running left to right.
/// Every color has a light and dark value under the same name; never hard-code a light value in a view.
enum Brand {
    // MARK: Color
    static let page = dynamic(0xEDE8E0, 0x171513)
    /// The lower band (timeline, years) and quiet fills.
    static let card = dynamic(0xE3DCD1, 0x221F1B)
    static let ink = dynamic(0x1C1A17, 0xEFE8DC)
    static let inkMuted = dynamic(0x5F554A, 0xA89E90)
    static let inkSoft = dynamic(0x3A342D, 0xCFC6B8)
    static let line = dynamic(0xD3CABD, 0x34302A)
    /// Oxblood. The one color for the main thing to tap.
    static let action = dynamic(0x7A2E2A, 0xD98A7E)
    static let onAction = dynamic(0xF7F1E8, 0x1A1210)
    /// The selected mark on a timeline, small accents. Same family as action.
    static let accent = dynamic(0x7A2E2A, 0xD98A7E)
    static let accentSoft = dynamic(0xE3DCD1, 0x221F1B)
    static let onAccentSoft = dynamic(0x1C1A17, 0xEFE8DC)
    static let error = dynamic(0xA3261E, 0xF2B8B5)

    /// Warm face fills behind initials, picked by name so a person keeps their tone.
    static let faceFills: [Color] = [
        dynamic(0xD8CDBE, 0x2C2823), dynamic(0xCFC2B0, 0x332E28), dynamic(0xDDD3C6, 0x29251F), dynamic(0xC9BBA8, 0x38322B),
    ]
    static let ringOuter = dynamic(0xE3DCD1, 0x221F1B)
    static let ringMiddle = dynamic(0xD8CDBE, 0x2C2823)
    static let ringInner = dynamic(0xCFC2B0, 0x332E28)

    static func faceFill(for name: String) -> Color {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return faceFills[sum % faceFills.count]
    }

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Big numbers (countdowns, day numbers): the light display serif.
    static func countdownFont(_ size: CGFloat) -> Font { display(size, relativeTo: .largeTitle) }

    /// The light display serif, for names and big numbers (Fraunces 72pt Light).
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle, italic: Bool = false) -> Font {
        guard TypeStyle.hasSerif else { return Font.system(size: size, weight: .light, design: .serif) }
        return Font.custom(italic ? TypeStyle.displayItalic : TypeStyle.displayLight, size: size, relativeTo: style)
    }

    /// The text serif, for sentences and quotes at reading sizes (Fraunces 9pt).
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .body, italic: Bool = false) -> Font {
        guard TypeStyle.hasSerif else { return Font.system(size: size, design: .serif) }
        if size >= 28 { return display(size, relativeTo: style, italic: italic) }
        return Font.custom(italic ? TypeStyle.textItalic : TypeStyle.textRegular, size: size, relativeTo: style)
    }

    // MARK: Spacing and radius
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 24
    static let space6: CGFloat = 32
    static let radiusSm: CGFloat = 4
    static let radiusMd: CGFloat = 4
    static let radiusLg: CGFloat = 6
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Type styles. Display styles use Fraunces (bundled); everything else is the system sans, so it reads clearly
/// and follows Dynamic Type. Eyebrows are small tracked capitals.
enum TypeStyle {
    case display, title, headline, body, bodyStrong, callout, caption, eyebrow

    static let displayLight = "Fraunces72pt-Light"
    static let displayItalic = "Fraunces72pt-LightItalic"
    static let textRegular = "Fraunces9pt-Regular"
    static let textItalic = "Fraunces9pt-Italic"
    static let hasSerif = UIFont(name: "Fraunces72pt-Light", size: 12) != nil

    var size: CGFloat {
        switch self {
        case .display: 44
        case .title: 34
        case .headline: 24
        case .body, .bodyStrong: 17
        case .callout: 15
        case .caption: 13
        case .eyebrow: 12
        }
    }

    var isSerif: Bool {
        switch self {
        case .display, .title, .headline: true
        default: false
        }
    }

    var weight: Font.Weight {
        switch self {
        case .bodyStrong: .semibold
        case .caption: .medium
        case .eyebrow: .semibold
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

    var font: Font {
        if isSerif { return Brand.display(size, relativeTo: relative) }
        return Font.system(relative, weight: weight)
    }

    /// The same size, emphasized.
    var strong: Font {
        if isSerif { return font }
        return Font.system(relative, weight: .semibold)
    }
}

extension View {
    func textStyle(_ style: TypeStyle, color: Color = Brand.ink) -> some View {
        self.font(style.font)
            .foregroundStyle(style == .eyebrow && color == Brand.ink ? Brand.inkMuted : color)
            .tracking(style == .eyebrow ? 1.6 : (style.isSerif ? -0.4 : 0))
            .textCase(style == .eyebrow ? .uppercase : nil)
    }
}
