import Foundation

/// How big a name is drawn in the display serif. Longer names step down in size first; past the smallest step the
/// name wraps onto a second line instead of being cut off ("Susan Holobaugh..." on build 1011).
enum NameSize {
    /// Home's featured name.
    static func featured(_ name: String) -> CGFloat {
        switch name.count {
        case ...5: 128
        case 6...8: 100
        case 9...12: 76
        default: 60
        }
    }

    /// A person's page.
    static func page(_ name: String) -> CGFloat {
        switch name.count {
        case ...7: 96
        case 8...11: 72
        case 12...16: 60
        default: 52
        }
    }

    /// Plan, holiday and other page titles.
    static func title(_ name: String) -> CGFloat {
        switch name.count {
        case ...9: 72
        case 10...14: 60
        default: 48
        }
    }

    /// Lines a name may use before it scales down further.
    static let maxLines = 2
}

/// A name for a sentence or title, without the emoji some contact cards carry ("Haiden 🕑" reads "Haiden").
enum DisplayName {
    static func plain(_ name: String) -> String {
        let kept = name.unicodeScalars.filter { s in
            let p = s.properties
            if s.value == 0xFE0F || s.value == 0x200D { return false }
            return !(p.isEmojiPresentation || (p.isEmoji && s.value > 0x238C))
        }
        let result = String(String.UnicodeScalarView(kept)).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? name : result
    }
}
