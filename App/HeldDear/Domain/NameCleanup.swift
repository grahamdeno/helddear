import Foundation

/// Tidying a typed name (Fable N1, N2, Nov 21, 2026). Plain rules, unit tested.
enum NameCleanup {
    /// Occasion words typed after a name come off it: "Mom anniversary" is Mom, "Sam's birthday" is Sam.
    /// A name that is only the word stays as typed.
    static func strip(_ name: String) -> String {
        let words = ["anniversary", "anniv", "birthday", "bday", "b-day"]
        var s = name.trimmingCharacters(in: .whitespacesAndNewlines)
        for w in words {
            for suffix in ["'s \(w)", "’s \(w)", "s \(w)", " \(w)"] where s.lowercased().hasSuffix(suffix) {
                let cut = String(s.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                if !cut.isEmpty { s = cut }
                break
            }
        }
        return s
    }

    /// Whether a typed name is someone already in the app: same name or full name, ignoring case and emoji.
    static func isSamePerson(_ typed: String, name: String, fullName: String) -> Bool {
        let t = DisplayName.plain(typed).lowercased()
        guard !t.isEmpty else { return false }
        return t == DisplayName.plain(name).lowercased() || t == DisplayName.plain(fullName).lowercased()
    }
}
