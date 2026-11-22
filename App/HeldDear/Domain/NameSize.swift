import Foundation

/// How big a name is drawn in the display serif. Longer names step down in size first; past the smallest step the
/// name wraps onto a second line instead of being cut off ("Miriam Hollowell..." on build 1011).
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

    /// The fixed height Home's featured name sits in, so the line under it stays put whatever the name's length.
    static let featuredSlot: CGFloat = 156

    /// How far Home's featured name sits lower over the medallion, with the line under it rising by the same amount,
    /// so more of the face shows and the name and line read together (Graham, Nov 21, 2026). The room comes from the
    /// space kept below the letters for tails like g and y, so a name with those keeps most of it.
    static func featuredDrop(_ name: String) -> CGFloat {
        let size = featured(name)
        let tails = name.contains { "gjpqyQ".contains($0) }
        return (size * (tails ? 0.06 : 0.2)).rounded()
    }

    /// Lines a name may use before it scales down further.
    static let maxLines = 2
}

/// A name for a sentence or title, without the emoji some contact cards carry ("Marcus 🕑" reads "Marcus").
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
