import SwiftUI
import UIKit

/// Hearth design system tokens (https://claude.ai/artifact/9D5FzJ3DKgKmnqQ3keut3K).
/// Every color has a light and dark value under the same name; never hard-code a light value in a view.
enum Brand {
    // MARK: Color
    static let page = dynamic(0xFFF4EC, 0x1F1720)
    static let card = dynamic(0xFFFFFF, 0x2C2230)
    static let ink = dynamic(0x3A2340, 0xF7ECE6)
    static let inkMuted = dynamic(0x6E5A66, 0xCBB8C2)
    static let line = dynamic(0xEBD8CB, 0x3D3040)
    /// Plum. The one color for things you tap.
    static let action = dynamic(0x5B2A5E, 0xD7A8D4)
    static let onAction = dynamic(0xFFFFFF, 0x2A1530)
    /// Coral. Small shapes only; never text, never a large fill.
    static let accent = dynamic(0xE8674A, 0xF07E62)
    /// Apricot. Tag fills.
    static let accentSoft = dynamic(0xF6B48F, 0x6B4334)
    static let onAccentSoft = dynamic(0x3A2340, 0xF7ECE6)
    static let error = dynamic(0xB3261E, 0xF2B8B5)

    /// Soft face fills behind initials, picked by name so a person keeps their color.
    static let faceFills: [Color] = [
        dynamic(0xF3D9C8, 0x4A3540), dynamic(0xE9D3E6, 0x46344A), dynamic(0xF6B48F, 0x6B4334), dynamic(0xEFE3DA, 0x3D3040),
    ]
    /// Ring fills for the "Your people" rings, outer to inner.
    static let ringOuter = dynamic(0xFBE8DC, 0x2F2433)
    static let ringMiddle = dynamic(0xF8D7C3, 0x45313A)
    static let ringInner = dynamic(0xF6B48F, 0x6B4334)

    static func faceFill(for name: String) -> Color {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return faceFills[sum % faceFills.count]
    }

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// The big countdown number (hero and widgets only). Tabular digits so it doesn't jitter.
    static func countdownFont(_ size: CGFloat) -> Font {
        let base = TypeStyle.hasNunito ? Font.custom("Nunito", size: size, relativeTo: .largeTitle) : Font.system(size: size, design: .rounded)
        return base.weight(.heavy).monospacedDigit()
    }

    // MARK: Spacing and radius
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 22
    static let space6: CGFloat = 32
    static let radiusSm: CGFloat = 12
    static let radiusMd: CGFloat = 22
    static let radiusLg: CGFloat = 32
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Type styles. Nunito is bundled; each style scales with Dynamic Type. SF Pro Rounded is the fallback.
enum TypeStyle {
    case display, title, headline, body, bodyStrong, callout, caption, eyebrow

    var size: CGFloat {
        switch self {
        case .display: 30
        case .title: 28
        case .headline: 20
        case .body, .bodyStrong: 17
        case .callout: 15
        case .caption: 13
        case .eyebrow: 12
        }
    }

    var weight: Font.Weight {
        switch self {
        case .display, .title, .headline, .eyebrow: .heavy
        case .body: .regular
        case .bodyStrong: .bold
        case .callout, .caption: .semibold
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

    static let hasNunito = UIFont.familyNames.contains("Nunito")

    var font: Font {
        if TypeStyle.hasNunito {
            return Font.custom("Nunito", size: size, relativeTo: relative).weight(weight)
        }
        return Font.system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    func textStyle(_ style: TypeStyle, color: Color = Brand.ink) -> some View {
        self.font(style.font)
            .foregroundStyle(color)
            .tracking(style == .eyebrow ? 1 : 0)
            .textCase(style == .eyebrow ? .uppercase : nil)
    }
}
