import Foundation

/// Who to ask for each person, the per-person switch, and what happened for each day (Graham, Nov 22, 2026).
/// Kept on this phone only (UserDefaults, not the settings that sync): names and numbers never leave it, except
/// in the texts the user sends from Messages.
final class FamilyCircle {
    static let shared = FamilyCircle()
    private let defaults: UserDefaults
    private let recipientsKey = "familyIn.recipients"
    private let overridesKey = "familyIn.on"
    private let recordsKey = "familyIn.records"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    // MARK: Who to ask

    func recipients(for personID: UUID) -> [FamilyIn.Recipient] { load(recipientsKey)[personID.uuidString] ?? [] }

    func setRecipients(_ list: [FamilyIn.Recipient], for personID: UUID) {
        var all: [String: [FamilyIn.Recipient]] = load(recipientsKey)
        all[personID.uuidString] = list.isEmpty ? nil : list
        save(all, recipientsKey)
    }

    /// Adds people, skipping anyone already on the list (same contact, or same number).
    func add(_ people: [FamilyIn.Recipient], for personID: UUID) {
        var list = recipients(for: personID)
        for p in people where !list.contains(where: { $0.id == p.id || ($0.phone != nil && $0.phone == p.phone) }) {
            list.append(p)
        }
        setRecipients(list, for: personID)
    }

    // MARK: The switch

    func override(for personID: UUID) -> Bool? { (defaults.dictionary(forKey: overridesKey) as? [String: Bool])?[personID.uuidString] }

    func setOn(_ on: Bool, for personID: UUID) {
        var all = (defaults.dictionary(forKey: overridesKey) as? [String: Bool]) ?? [:]
        all[personID.uuidString] = on
        defaults.set(all, forKey: overridesKey)
    }

    // MARK: Each day

    func record(for momentID: UUID) -> FamilyIn.Record { load(recordsKey)[momentID.uuidString] ?? FamilyIn.Record() }

    func update(_ momentID: UUID, _ change: (inout FamilyIn.Record) -> Void) {
        var all: [String: FamilyIn.Record] = load(recordsKey)
        var r = all[momentID.uuidString] ?? FamilyIn.Record()
        change(&r)
        all[momentID.uuidString] = r
        save(all, recordsKey)
    }

    // MARK: Storage

    private func load<T: Decodable>(_ key: String) -> [String: T] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: T].self, from: data)) ?? [:]
    }

    private func save<T: Encodable>(_ value: [String: T], _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
