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
    /// A lighter sheet that content sits on, so sections read as separate things (feedback on build 1016).
    static let raised = dynamic(0xF8F4EE, 0x2E2A25)
    /// Borders and dividers reach 3:1 against the page (Fable's audit UX-7, Nov 24, 2026), and darken further with
    /// Increase Contrast.
    static let raisedLine = dynamic(0x8F8475, 0x847A6D, high: (0x6E6457, 0xA39888))
    static let ink = dynamic(0x1C1A17, 0xEFE8DC)
    /// With Increase Contrast, muted text is drawn as dark as the soft ink.
    static let inkMuted = dynamic(0x5F554A, 0xA89E90, high: (0x3A342D, 0xCFC6B8))
    static let inkSoft = dynamic(0x3A342D, 0xCFC6B8)
    static let line = dynamic(0x857A6B, 0x847A6D, high: (0x6E6457, 0xA39888))
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

    private static func dynamic(_ light: UInt32, _ dark: UInt32, high: (UInt32, UInt32)? = nil) -> Color {
        Color(UIColor { traits in
            let dark_ = traits.userInterfaceStyle == .dark
            if let high, traits.accessibilityContrast == .high { return UIColor(hex: dark_ ? high.1 : high.0) }
            return UIColor(hex: dark_ ? dark : light)
        })
    }

    /// The colors with their light and dark values, for the contrast test.
    static let contrastPairs: [(name: String, light: UInt32, dark: UInt32)] = [
        ("line", 0x857A6B, 0x847A6D), ("raisedLine", 0x8F8475, 0x847A6D),
        ("inkMuted", 0x5F554A, 0xA89E90), ("inkSoft", 0x3A342D, 0xCFC6B8), ("ink", 0x1C1A17, 0xEFE8DC),
    ]
    static let pageHex: (light: UInt32, dark: UInt32) = (0xEDE8E0, 0x171513)

    /// Big numbers (countdowns, day numbers): the light display serif.
    static func countdownFont(_ size: CGFloat) -> Font { display(size, relativeTo: .largeTitle) }

    /// The light display serif, for names and big numbers (Fraunces 72pt Light). With Bold Text on, the heavier
    /// Fraunces text cut is used instead, so names and headings get bolder too (Fable's audit UX-3, Nov 24, 2026).
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle, italic: Bool = false) -> Font {
        let bold = UIAccessibility.isBoldTextEnabled
        guard TypeStyle.hasSerif else { return Font.system(size: size, weight: bold ? .semibold : .light, design: .serif) }
        if bold { return Font.custom(italic ? TypeStyle.textItalic : TypeStyle.textRegular, size: size, relativeTo: style).weight(.semibold) }
        return Font.custom(italic ? TypeStyle.displayItalic : TypeStyle.displayLight, size: size, relativeTo: style)
    }

    /// The text serif, for sentences and quotes at reading sizes (Fraunces 9pt).
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .body, italic: Bool = false) -> Font {
        guard TypeStyle.hasSerif else { return Font.system(size: size, design: .serif) }
        if size >= 28 { return display(size, relativeTo: style, italic: italic) }
        let font = Font.custom(italic ? TypeStyle.textItalic : TypeStyle.textRegular, size: size, relativeTo: style)
        return UIAccessibility.isBoldTextEnabled ? font.weight(.semibold) : font
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
        case .caption: 15
        case .eyebrow: 13
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
        // Captions and eyebrows are the subheadline and footnote sizes (15 and 13 pt at default text size), so small
        // text stays readable (Fable's audit UX-1, Nov 24, 2026). Both still grow with the user's text size.
        case .caption: .subheadline
        case .eyebrow: .footnote
        }
    }

    /// The ink a style is drawn in: eyebrows default to soft ink, and small text asked to be muted gets soft ink.
    static func ink(for style: TypeStyle, requested: Color) -> Color {
        let small = style == .caption || style == .eyebrow
        if style == .eyebrow && requested == Brand.ink { return Brand.inkSoft }
        if small && requested == Brand.inkMuted { return Brand.inkSoft }
        return requested
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
    /// Small text (captions, eyebrows) never uses the muted ink: it's drawn in the soft ink instead (UX-1).
    func textStyle(_ style: TypeStyle, color: Color = Brand.ink) -> some View {
        self.font(style.font)
            .foregroundStyle(TypeStyle.ink(for: style, requested: color))
            .tracking(style == .eyebrow ? 1.6 : (style.isSerif ? -0.4 : 0))
            .textCase(style == .eyebrow ? .uppercase : nil)
    }
}
