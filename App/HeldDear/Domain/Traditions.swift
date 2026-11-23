import Foundation

/// A holiday tradition (Graham, Nov 22, 2026): the same thing for the same people every year, like an ornament for
/// each kid at Christmas. Set up once on the holiday's page; it lands in each chosen person's plan every year, starting
/// this one, each with its own steps. Kept with the settings that sync through iCloud.
struct Tradition: Codable, Identifiable, Equatable {
    var id = UUID()
    /// The holiday, as HolidayRef.raw ("christmas", "custom:Hanukkah").
    var holiday: String
    var name: String
    /// Who it's from; empty means you.
    var giverIDs: [UUID] = []
    var recipientIDs: [UUID] = []
    var on = true
    /// The days it was already added to, so it's added once per year and stays out if removed from a plan.
    var applied: [UUID] = []
}

enum Traditions {
    static let defaultsKey = "holidayTraditions"

    static func all(_ d: UserDefaults = .standard) -> [Tradition] {
        guard let data = d.data(forKey: defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([Tradition].self, from: data)) ?? []
    }

    static func save(_ list: [Tradition], _ d: UserDefaults = .standard) {
        d.set(try? JSONEncoder().encode(list), forKey: defaultsKey)
    }

    static func upsert(_ t: Tradition, _ d: UserDefaults = .standard) {
        var list = all(d)
        if let i = list.firstIndex(where: { $0.id == t.id }) { list[i] = t } else { list.append(t) }
        save(list, d)
    }

    static func remove(_ id: UUID, _ d: UserDefaults = .standard) { save(all(d).filter { $0.id != id }, d) }

    static func forHoliday(_ raw: String, _ d: UserDefaults = .standard) -> [Tradition] { all(d).filter { $0.holiday == raw } }

    /// The days a tradition still needs adding to: on, for a chosen person, and not added before.
    static func toAdd(_ t: Tradition, days: [(dayID: UUID, personID: UUID)]) -> [UUID] {
        guard t.on, !t.name.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let people = Set(t.recipientIDs), done = Set(t.applied)
        return days.filter { people.contains($0.personID) && !done.contains($0.dayID) }.map(\.dayID)
    }
}
