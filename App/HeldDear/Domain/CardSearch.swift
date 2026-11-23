import Foundation

/// Finding a mailed card (Graham, Nov 22, 2026): Handwrytten's categories as one menu, and a search across every
/// card's name, description and category. Forgiving about apostrophes, case and a few everyday words. Plain rules,
/// unit tested.
enum CardSearch {
    /// Words that mean the same when looking for a card.
    private static let alike: [String: [String]] = [
        "mom": ["mother", "mum", "mama"], "mother": ["mom", "mum", "mama"],
        "dad": ["father", "papa"], "father": ["dad", "papa"],
        "xmas": ["christmas"], "christmas": ["xmas", "holiday"],
        "bday": ["birthday"], "birthday": ["bday"],
        "thanks": ["thank"], "thank": ["thanks"],
        "love": ["valentine", "anniversary"],
    ]

    /// Lowercased, apostrophes and punctuation gone, single spaces: "Mother's Day!" reads "mothers day".
    static func normalize(_ s: String) -> String {
        let lowered = s.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\u{2019}", with: "")
        let kept = lowered.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    /// True when every word of the search is found, as a word start, in the card's name, description or category,
    /// or one of its everyday alikes is ("mom" finds "Mother's Day").
    static func matches(_ query: String, name: String, description: String?, category: String?) -> Bool {
        let words = normalize(query).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return true }
        let hay = " " + normalize([name, description ?? "", category ?? ""].joined(separator: " "))
        return words.allSatisfy { w in
            let options = [w] + (alike[w] ?? []) + (w.hasSuffix("s") ? [String(w.dropLast())] : [])
            return options.contains { hay.contains(" " + $0) }
        }
    }

    /// The menu's starting category: the occasion's own when it's in the list, else the first.
    static func startingSection(own: String?, names: [String]) -> String? {
        if let own, names.contains(own) { return own }
        return names.first
    }
}
