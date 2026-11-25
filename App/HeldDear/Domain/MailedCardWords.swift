import Foundation

/// Words for a mailed card on the person's plan and year (Graham, Nov 25, 2026).
enum MailedCardWords {
    /// The plan item once it's mailed: "A handwritten card, mailed (Flower Buds)".
    static func title(_ cardName: String) -> String {
        "A handwritten card, mailed (\(cardName.trimmingCharacters(in: .whitespaces)))"
    }

    /// The card's message as the year's line, in quotes, cut at a word near 120 characters.
    static func messageLine(_ message: String, limit: Int = 120) -> String? {
        let text = message.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        guard text.count > limit else { return "\u{201C}\(text)\u{201D}" }
        let cut = text.prefix(limit)
        let atWord = cut.lastIndex(of: " ").map { cut[..<$0] } ?? cut
        return "\u{201C}\(atWord.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces)))\u{2026}\u{201D}"
    }
}
