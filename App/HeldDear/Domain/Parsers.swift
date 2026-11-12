import Foundation

struct ParsedBirthday: Equatable {
    var name: String
    var month: Int
    var day: Int
    var year: Int?
}

/// Reads "Mike, March 3", "March 3 Mike", "Mike 3/3", "Mike's birthday is Mar 3rd, 1980".
enum BirthdayParser {
    private static let months: [String: Int] = {
        var map: [String: Int] = [:]
        let names = ["january", "february", "march", "april", "may", "june", "july",
                     "august", "september", "october", "november", "december"]
        for (i, n) in names.enumerated() {
            map[n] = i + 1
            map[String(n.prefix(3))] = i + 1
        }
        map["sept"] = 9
        return map
    }()

    private static let stopWords: Set<String> = ["birthday", "bday", "b-day", "is", "on", "the", "of", "born"]

    static func parse(_ raw: String) -> ParsedBirthday? {
        let cleaned = raw.replacingOccurrences(of: ",", with: " ")
        var tokens = cleaned.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !tokens.isEmpty else { return nil }

        var month: Int?
        var day: Int?
        var year: Int?
        var used = Set<Int>()

        // Numeric month/day(/year).
        for (i, t) in tokens.enumerated() {
            let parts = t.split(separator: "/").map(String.init)
            if parts.count >= 2, let m = Int(parts[0]), let d = Int(parts[1]), (1...12).contains(m) {
                month = m; day = d; used.insert(i)
                if parts.count == 3, let y = Int(parts[2]) { year = y < 100 ? (y > 30 ? 1900 + y : 2000 + y) : y }
                break
            }
        }

        // Month name with a day beside it.
        if month == nil {
            for (i, t) in tokens.enumerated() {
                let key = t.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
                guard let m = months[key] else { continue }
                if i + 1 < tokens.count, let d = dayNumber(tokens[i + 1]) {
                    month = m; day = d; used.formUnion([i, i + 1])
                    if i + 2 < tokens.count, let y = Int(tokens[i + 2]), (1900...2100).contains(y) {
                        year = y; used.insert(i + 2)
                    }
                    break
                }
                if i > 0, let d = dayNumber(tokens[i - 1]) {
                    month = m; day = d; used.formUnion([i - 1, i])
                    if i + 1 < tokens.count, let y = Int(tokens[i + 1]), (1900...2100).contains(y) {
                        year = y; used.insert(i + 1)
                    }
                    break
                }
            }
        }

        guard let m = month, let d = day, isValid(month: m, day: d) else { return nil }

        tokens = tokens.enumerated().filter { !used.contains($0.offset) }.map(\.element)
        let nameWords = tokens.compactMap { word -> String? in
            var w = word
            for suffix in ["'s", "’s"] where w.lowercased().hasSuffix(suffix) { w = String(w.dropLast(2)) }
            return stopWords.contains(w.lowercased()) || w.isEmpty ? nil : w
        }
        let name = nameWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return ParsedBirthday(name: name, month: m, day: d, year: year)
    }

    private static func dayNumber(_ token: String) -> Int? {
        var t = token.lowercased()
        for suffix in ["st", "nd", "rd", "th"] where t.hasSuffix(suffix) { t = String(t.dropLast(2)) }
        guard let d = Int(t), (1...31).contains(d) else { return nil }
        return d
    }

    static func isValid(month: Int, day: Int) -> Bool {
        let maxDay = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return (1...12).contains(month) && day >= 1 && day <= maxDay[month - 1]
    }
}

/// Reads "Nora wants blue skates" against the names the user already has.
enum WishParser {
    private static let connectors = ["would really like", "would like", "wants", "wanted", "mentioned", "likes",
                                     "needs", "loves", "asked for", "-", ":", "–"]

    /// Returns the index of the matched name (longest match wins) and the wish text without the name.
    static func parse(_ raw: String, names: [String]) -> (index: Int?, text: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        var best: (index: Int, length: Int)?
        for (i, name) in names.enumerated() {
            let n = name.lowercased().trimmingCharacters(in: .whitespaces)
            guard !n.isEmpty, lower.hasPrefix(n) else { continue }
            let rest = lower.dropFirst(n.count)
            guard rest.isEmpty || rest.first == " " || rest.first == ":" || rest.hasPrefix("'s") || rest.hasPrefix("’s") else { continue }
            if best == nil || n.count > best!.length { best = (i, n.count) }
        }
        guard let match = best else { return (nil, trimmed) }
        var text = String(trimmed.dropFirst(match.length))
        if text.lowercased().hasPrefix("'s") || text.lowercased().hasPrefix("’s") { text = String(text.dropFirst(2)) }
        text = text.trimmingCharacters(in: .whitespaces)
        for c in connectors where text.lowercased().hasPrefix(c) {
            text = String(text.dropFirst(c.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        return (match.index, text.isEmpty ? trimmed : text)
    }
}
