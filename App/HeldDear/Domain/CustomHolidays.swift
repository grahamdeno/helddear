import Foundation

/// One shared holiday, built in or added by the user (story 2.10). Pages, routes and groups use this instead of the
/// bare type so two added holidays never mix.
struct HolidayRef: Hashable {
    let type: OccasionType
    /// The name of a holiday the user added; nil for built-in holidays.
    let name: String?

    init(type: OccasionType, name: String? = nil) {
        self.type = type
        self.name = type == .custom ? name : nil
    }

    var label: String { type.title(partner: name) }

    /// "christmas", or "custom:Hanukkah" for a holiday the user added.
    var raw: String { type == .custom ? "custom:\(name ?? "")" : type.rawValue }

    init?(raw: String) {
        if raw.hasPrefix("custom:") {
            let name = String(raw.dropFirst("custom:".count))
            guard !name.isEmpty else { return nil }
            self.init(type: .custom, name: name)
        } else if let t = OccasionType(rawValue: raw), t.kind == .holiday, t != .custom {
            self.init(type: t)
        } else {
            return nil
        }
    }

    func matches(type t: OccasionType, partner: String?) -> Bool {
        guard t == type else { return false }
        return type != .custom || CustomHolidays.sameName(partner ?? "", name ?? "")
    }
}

/// Holidays the user adds: a name and the same date each year. Kept on the phone in UserDefaults; each person in one
/// gets an ordinary Occasion (type `custom`, the name in `partnerName`), so SwiftData's schema doesn't change.
struct CustomHoliday: Codable, Equatable, Identifiable {
    var name: String
    var month: Int
    var day: Int
    var id: String { name.lowercased() }
    var ref: HolidayRef { HolidayRef(type: .custom, name: name) }
}

enum CustomHolidays {
    static let defaultsKey = "customHolidays"

    static func all(_ defaults: UserDefaults = .standard) -> [CustomHoliday] {
        guard let data = defaults.data(forKey: defaultsKey),
              let list = try? JSONDecoder().decode([CustomHoliday].self, from: data) else { return [] }
        return list.sorted { ($0.month, $0.day) < ($1.month, $1.day) }
    }

    static func save(_ list: [CustomHoliday], _ defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(list), forKey: defaultsKey)
    }

    static func find(_ name: String, _ defaults: UserDefaults = .standard) -> CustomHoliday? {
        all(defaults).first { sameName($0.name, name) }
    }

    static func sameName(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(b.trimmingCharacters(in: .whitespaces)) == .orderedSame
    }

    enum Problem: Equatable { case empty, taken, badDate }

    /// Why a name and date can't be used, or nil. Names built into the app and names already added are taken.
    static func problem(name: String, month: Int, day: Int, existing: [CustomHoliday], except: String? = nil) -> Problem? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        let builtIn = OccasionType.allCases.filter { $0.kind == .holiday && $0 != .custom }.map(\.label)
        if builtIn.contains(where: { sameName($0, trimmed) }) { return .taken }
        if existing.contains(where: { sameName($0.name, trimmed) && !(except.map { sameName($0, trimmed) } ?? false) }) {
            return .taken
        }
        // 2028 is a leap year, so February 29 counts.
        guard DateComponents(calendar: Calendar(identifier: .gregorian), year: 2028, month: month, day: day).isValidDate
        else { return .badDate }
        return nil
    }

    static func problemText(_ p: Problem) -> String {
        switch p {
        case .empty: "Give it a name."
        case .taken: "That name is already in Held Dear."
        case .badDate: "Pick a real date."
        }
    }

    /// Adds or replaces a holiday by name (`replacing` is the old name when renaming).
    static func upsert(_ h: CustomHoliday, replacing old: String? = nil, _ defaults: UserDefaults = .standard) {
        var list = all(defaults).filter { !sameName($0.name, old ?? h.name) && !sameName($0.name, h.name) }
        list.append(CustomHoliday(name: h.name.trimmingCharacters(in: .whitespacesAndNewlines), month: h.month, day: h.day))
        save(list, defaults)
    }

    static func remove(_ name: String, _ defaults: UserDefaults = .standard) {
        save(all(defaults).filter { !sameName($0.name, name) }, defaults)
    }
}
